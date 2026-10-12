# Consultas de estatísticas de resolução de questões de um usuário.
#
# Antes ficavam escritas dentro do ResolucoesController. Agora o controller
# (página de estatísticas do site) e as ferramentas do MCP chamam o mesmo
# código, então os números são sempre iguais nos dois lugares.
#
# Regras que valem aqui:
# - Estatísticas globais ignoram resoluções importadas (importada_de_id), que
#   são cópias trazidas para um caderno por "Atualizar resoluções".
# - Estatísticas de um caderno contam todas as resoluções daquele caderno,
#   inclusive as importadas.
#
# Uso:
#   inicio, fim = EstatisticasService.periodo(days: 30)
#   EstatisticasService.new(user).por_disciplina(inicio, fim)
class EstatisticasService
  DIAS_PADRAO = 30

  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Intervalo [inicio, fim] a partir de start_date/end_date ou de days.
  # Mesma regra que o ResolucoesController sempre usou.
  def self.periodo(days: nil, start_date: nil, end_date: nil)
    if start_date.present? && end_date.present?
      [start_date.to_date.beginning_of_day, end_date.to_date.end_of_day]
    else
      dias = days.to_i > 0 ? days.to_i : DIAS_PADRAO
      [dias.days.ago.beginning_of_day, Time.current.end_of_day]
    end
  end

  # Taxa de acerto em %, com uma casa decimal.
  def self.taxa(acertos, total)
    total = total.to_i
    return 0.0 if total.zero?

    (acertos.to_f / total * 100).round(1)
  end

  # ---------------------------------------------------------------------------
  # Estatísticas de todos os usuários (painel admin)
  # ---------------------------------------------------------------------------

  def self.global(desde)
    query = <<-SQL
      SELECT
        created_at::date as date,
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE created_at >= :start_date
        AND importada_de_id IS NULL
      GROUP BY date
      ORDER BY date DESC
    SQL

    stats = select_all(query, start_date: desde)

    summary_query = <<-SQL
      SELECT
        count(*) as total,
        sum(case when correta then 1 else 0 end) as acertos,
        sum(case when not correta then 1 else 0 end) as erros,
        count(DISTINCT user_id) as total_usuarios
      FROM resolucaos
      WHERE created_at >= :start_date
        AND importada_de_id IS NULL
    SQL

    summary = Resolucao.connection.select_one(
      ActiveRecord::Base.sanitize_sql_array([summary_query, { start_date: desde }])
    ).transform_values(&:to_i)

    { daily_stats: stats, summary: summary }
  end

  # ---------------------------------------------------------------------------
  # Estatísticas do usuário
  # ---------------------------------------------------------------------------

  # Resoluções por dia, da mais recente para a mais antiga.
  def por_dia(inicio, fim)
    query = <<-SQL
      SELECT
        created_at::date as date,
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE user_id = :user_id
        AND importada_de_id IS NULL
        AND created_at >= :start_date
        AND created_at <= :end_date
      GROUP BY date
      ORDER BY date DESC
    SQL

    select_all(query, user_id: user.id, start_date: inicio, end_date: fim)
  end

  # Totais do período (novo; usado pelo MCP).
  def resumo(inicio, fim)
    query = <<-SQL
      SELECT
        count(*) as total_resolucoes,
        count(DISTINCT questao_id) as questoes_distintas,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros,
        count(DISTINCT created_at::date) as dias_com_estudo
      FROM resolucaos
      WHERE user_id = :user_id
        AND importada_de_id IS NULL
        AND created_at >= :start_date
        AND created_at <= :end_date
    SQL

    row = Resolucao.connection.select_one(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: user.id, start_date: inicio, end_date: fim }])
    ).to_h.transform_values(&:to_i)

    row.merge('taxa_acerto' => self.class.taxa(row['total_acertos'], row['total_resolucoes']))
  end

  def por_disciplina(inicio, fim)
    query = <<-SQL
      SELECT
        d.nome as disciplina_nome,
        d.id as disciplina_id,
        count(r.*) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN disciplinas d ON q.disciplina_id = d.id
      WHERE r.user_id = :user_id
        AND r.importada_de_id IS NULL
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date
      GROUP BY d.nome, d.id
      ORDER BY total_resolucoes DESC
    SQL

    select_all(query, user_id: user.id, start_date: inicio, end_date: fim)
  end

  def por_assunto(inicio, fim, disciplina_id: nil)
    sql = "SELECT
        COALESCE(a.nome, 'Sem Assunto') as assunto_nome,
        count(r.*) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      WHERE r.user_id = :user_id
        AND r.importada_de_id IS NULL
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date"
    binds = { user_id: user.id, start_date: inicio, end_date: fim }

    if disciplina_id.present?
      sql += " AND q.disciplina_id = :disciplina_id"
      binds[:disciplina_id] = disciplina_id
    end

    sql += " GROUP BY COALESCE(a.nome, 'Sem Assunto') ORDER BY total_resolucoes DESC"

    select_all(sql, **binds)
  end

  # Disciplina > assunto > tópico, ordenado da maior para a menor taxa de acerto.
  # Quem chama verifica a permissão do plano (show_stats_table_by_assunto_basic).
  def hierarquia(inicio, fim)
    query = <<-SQL
      SELECT
        d.id as disciplina_id, d.nome as disciplina_nome,
        a.id as assunto_id, a.nome as assunto_nome,
        t.id as topico_id, t.nome as topico_nome,
        count(r.id) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      LEFT JOIN topicos t ON q.topico_id = t.id
      WHERE r.user_id = :user_id
        AND r.importada_de_id IS NULL
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date
      GROUP BY d.id, d.nome, a.id, a.nome, t.id, t.nome
      ORDER BY d.nome, a.nome, t.nome
    SQL

    results = select_all(query, user_id: user.id, start_date: inicio, end_date: fim)
    montar_hierarquia(results)
  end

  # Assuntos com pior taxa de acerto no período, considerando só os que têm
  # pelo menos `minimo_resolucoes` (para não destacar assunto com 1 erro em 1).
  def pontos_fracos(inicio, fim, limite: 10, minimo_resolucoes: 5, disciplina_id: nil)
    sql = <<-SQL
      SELECT
        d.id as disciplina_id, d.nome as disciplina_nome,
        a.id as assunto_id, COALESCE(a.nome, 'Sem Assunto') as assunto_nome,
        count(r.id) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      WHERE r.user_id = :user_id
        AND r.importada_de_id IS NULL
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date
    SQL
    binds = { user_id: user.id, start_date: inicio, end_date: fim, minimo: minimo_resolucoes.to_i, limite: limite.to_i }

    if disciplina_id.present?
      sql += " AND q.disciplina_id = :disciplina_id"
      binds[:disciplina_id] = disciplina_id.to_i
    end

    sql += <<-SQL
      GROUP BY d.id, d.nome, a.id, a.nome
      HAVING count(r.id) >= :minimo
      ORDER BY (sum(case when r.correta then 1 else 0 end)::float / count(r.id)) ASC, count(r.id) DESC
      LIMIT :limite
    SQL

    select_all(sql, **binds).map do |row|
      row.merge('taxa_acerto' => self.class.taxa(row['total_acertos'], row['total_resolucoes']))
    end
  end

  # Questões que o usuário errou ao menos uma vez no período, da resolução mais
  # recente para a mais antiga. Informa se a última tentativa foi acerto, o que
  # ajuda a separar o que já foi corrigido do que ainda está pendente.
  #
  # Com caderno, olha só as resoluções daquele caderno (inclusive importadas),
  # como a página de estatísticas do caderno. Com apenas_pendentes, deixa de
  # fora as questões cuja última tentativa já foi acerto.
  def questoes_erradas(inicio: nil, fim: nil, caderno_id: nil, limite: 50, apenas_pendentes: false)
    sql = <<-SQL
      WITH por_questao AS (
        SELECT
          r.questao_id,
          count(*) as tentativas,
          sum(case when not r.correta then 1 else 0 end) as erros,
          max(r.created_at) as ultima_resolucao_em,
          (array_agg(r.correta ORDER BY r.created_at DESC))[1] as ultima_correta,
          (array_agg(r.resposta ORDER BY r.created_at DESC))[1] as ultima_resposta
        FROM resolucaos r
        WHERE r.user_id = :user_id
    SQL
    binds = { user_id: user.id, limite: limite.to_i }

    if caderno_id.present?
      sql += " AND r.caderno_id = :caderno_id"
      binds[:caderno_id] = caderno_id.to_i
    else
      sql += " AND r.importada_de_id IS NULL"
    end

    if inicio && fim
      sql += " AND r.created_at >= :start_date AND r.created_at <= :end_date"
      binds[:start_date] = inicio
      binds[:end_date] = fim
    end

    sql += <<-SQL
        GROUP BY r.questao_id
        HAVING sum(case when not r.correta then 1 else 0 end) > 0
      )
      SELECT
        pq.questao_id, pq.tentativas, pq.erros, pq.ultima_resolucao_em,
        pq.ultima_correta, pq.ultima_resposta,
        q.ano, d.nome as disciplina_nome, a.nome as assunto_nome, t.nome as topico_nome
      FROM por_questao pq
      JOIN questaos q ON q.id = pq.questao_id
      LEFT JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      LEFT JOIN topicos t ON q.topico_id = t.id
      #{'WHERE NOT pq.ultima_correta' if apenas_pendentes}
      ORDER BY pq.ultima_resolucao_em DESC
      LIMIT :limite
    SQL

    select_all(sql, **binds)
  end

  # IDs de questões para um caderno gerado a partir das estatísticas
  # (ResolucoesController#gerar_caderno_stats).
  def questoes_para_caderno(disciplina_ids:, assunto_ids:, topico_ids:, only_errors:, periodo: nil)
    questaos = Questao.all

    classificacoes_filters = []
    classificacoes_filters += disciplina_ids.map { |id| "d_#{id}" } if disciplina_ids.present?
    classificacoes_filters += assunto_ids.map { |id| "a_#{id}" } if assunto_ids.present?
    classificacoes_filters += topico_ids.map { |id| "t_#{id}" } if topico_ids.present?

    or_clauses = []
    or_clauses << "classificacoes && ?" if classificacoes_filters.present?
    or_clauses << "questaos.disciplina_id IN (?)" if disciplina_ids.present?
    or_clauses << "questaos.assunto_id IN (?)" if assunto_ids.present?
    or_clauses << "questaos.topico_id IN (?)" if topico_ids.present?

    clause_args = []
    clause_args << "{#{classificacoes_filters.join(',')}}" if classificacoes_filters.present?
    clause_args << disciplina_ids if disciplina_ids.present?
    clause_args << assunto_ids if assunto_ids.present?
    clause_args << topico_ids if topico_ids.present?

    questaos = questaos.where(or_clauses.join(' OR '), *clause_args) if or_clauses.present?

    if only_errors
      questaos = questaos.joins(:resolucoes)
                         .where(resolucaos: { user_id: user.id, correta: false })
      questaos = questaos.where(resolucaos: { created_at: periodo[0]..periodo[1] }) if periodo
    end

    questaos.distinct.pluck(:id)
  end

  # Acertos, erros e total por caderno, numa consulta só.
  # Retorna { caderno_id => { acertos:, erros:, respondidas: } }.
  def contagens_por_caderno(caderno_ids)
    return {} if caderno_ids.blank?

    contagens = Resolucao.where(caderno_id: caderno_ids).group(:caderno_id, :correta).count
    caderno_ids.index_with do |id|
      acertos = contagens[[id, true]] || 0
      erros = contagens[[id, false]] || 0
      { acertos: acertos, erros: erros, respondidas: acertos + erros + (contagens[[id, nil]] || 0) }
    end
  end

  # Resumo e hierarquia de um caderno, considerando a resolução mais recente de
  # cada questão. Mesma resposta de GET /resolucoes/notebook_stats.
  def caderno(caderno)
    questao_ids = caderno.questoes_ids || []
    return { summary: {}, hierarchy: [] } if questao_ids.empty?

    summary_query = <<-SQL
      SELECT
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE user_id = :user_id
        AND caderno_id = :caderno_id
    SQL

    summary = select_all(summary_query, user_id: user.id, caderno_id: caderno.id).first

    hierarchy_query = <<-SQL
      WITH latest_resolutions AS (
        SELECT DISTINCT ON (questao_id)
          id, correta, questao_id
        FROM resolucaos
        WHERE user_id = :user_id AND caderno_id = :caderno_id
        ORDER BY questao_id, created_at DESC
      )
      SELECT
        d.id as disciplina_id, d.nome as disciplina_nome,
        a.id as assunto_id, a.nome as assunto_nome,
        t.id as topico_id, t.nome as topico_nome,
        q.id as questao_id,
        lr.id as resolucao_id,
        lr.correta as correta
      FROM questaos q
      JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      LEFT JOIN topicos t ON q.topico_id = t.id
      LEFT JOIN latest_resolutions lr ON lr.questao_id = q.id
      WHERE q.id IN (:questao_ids)
    SQL

    results = select_all(hierarchy_query, user_id: user.id, caderno_id: caderno.id, questao_ids: questao_ids)
    hierarchy, resolvidas_ids = montar_hierarquia_caderno(results)

    { summary: summary, hierarchy: hierarchy, resolvidas_ids: resolvidas_ids }
  end

  # Estatísticas de uma questão: de todos os usuários, do usuário e o histórico.
  def questao(questao_id)
    global_query = <<-SQL
      SELECT
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros,
        count(DISTINCT user_id) as total_users
      FROM resolucaos
      WHERE questao_id = :questao_id
        AND importada_de_id IS NULL
    SQL

    personal_query = <<-SQL
      SELECT
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE questao_id = :questao_id AND user_id = :user_id
        AND importada_de_id IS NULL
    SQL

    history = user.resolucoes
                  .originais
                  .where(questao_id: questao_id)
                  .order(created_at: :desc)
                  .select(:id, :resposta, :correta, :created_at)

    {
      global: select_all(global_query, questao_id: questao_id).first,
      personal: select_all(personal_query, questao_id: questao_id, user_id: user.id).first,
      history: history
    }
  end

  private

  def self.select_all(sql, **binds)
    Resolucao.connection.select_all(ActiveRecord::Base.sanitize_sql_array([sql, binds])).to_a
  end
  private_class_method :select_all

  def select_all(sql, **binds)
    self.class.send(:select_all, sql, **binds)
  end

  def montar_hierarquia(results)
    disciplinas_map = {}

    results.each do |row|
      d_id = row['disciplina_id']
      a_id = row['assunto_id']
      t_id = row['topico_id']

      d = disciplinas_map[d_id] ||= {
        id: d_id, name: row['disciplina_nome'],
        total_resolucoes: 0,
        acertos: 0,
        erros: 0,
        assuntos: {}
      }

      d[:total_resolucoes] += row['total_resolucoes'].to_i
      d[:acertos] += row['total_acertos'].to_i
      d[:erros] += row['total_erros'].to_i

      assunto_id = a_id || "sem-assunto-#{d_id}"
      assunto_nome = row['assunto_nome'] || "Sem Assunto"

      a = d[:assuntos][assunto_id] ||= {
        id: assunto_id, name: assunto_nome,
        total_resolucoes: 0,
        acertos: 0,
        erros: 0,
        topicos: {}
      }
      a[:total_resolucoes] += row['total_resolucoes'].to_i
      a[:acertos] += row['total_acertos'].to_i
      a[:erros] += row['total_erros'].to_i

      if t_id.present?
        t = a[:topicos][t_id] ||= {
          id: t_id,
          name: row['topico_nome'] || "Tópico ##{t_id}",
          total_resolucoes: 0,
          acertos: 0,
          erros: 0
        }
        t[:total_resolucoes] += row['total_resolucoes'].to_i
        t[:acertos] += row['total_acertos'].to_i
        t[:erros] += row['total_erros'].to_i
      end
    end

    taxa = ->(item) { item[:total_resolucoes] > 0 ? item[:acertos].to_f / item[:total_resolucoes] : 0 }

    disciplinas_map.values.map do |d|
      {
        id: d[:id],
        name: d[:name],
        total_resolucoes: d[:total_resolucoes],
        acertos: d[:acertos],
        erros: d[:erros],
        assuntos: d[:assuntos].values.map do |a|
          {
            id: a[:id],
            name: a[:name],
            total_resolucoes: a[:total_resolucoes],
            acertos: a[:acertos],
            erros: a[:erros],
            topicos: a[:topicos].values.sort_by(&taxa).reverse
          }
        end.sort_by(&taxa).reverse
      }
    end.sort_by(&taxa).reverse
  end

  def montar_hierarquia_caderno(results)
    disciplinas_map = {}
    resolvidas_ids = []

    results.each do |row|
      d_id = row['disciplina_id']
      a_id = row['assunto_id']
      t_id = row['topico_id']
      q_id = row['questao_id']
      res_correta = row['correta']
      has_res = !row['resolucao_id'].nil?

      resolvidas_ids << q_id.to_i if has_res

      d = disciplinas_map[d_id] ||= {
        id: d_id, name: row['disciplina_nome'],
        total_questoes_ids: Set.new,
        resolvidas_ids: Set.new,
        acertos_ids: Set.new,
        assuntos: {}
      }
      d[:total_questoes_ids] << q_id
      if has_res
        d[:resolvidas_ids] << q_id
        d[:acertos_ids] << q_id if res_correta
      end

      assunto_id = a_id || "sem-assunto-#{d_id}"
      assunto_nome = row['assunto_nome'] || "Sem Assunto"

      a = d[:assuntos][assunto_id] ||= {
        id: assunto_id, name: assunto_nome,
        total_questoes_ids: Set.new,
        resolvidas_ids: Set.new,
        acertos_ids: Set.new,
        topicos: {}
      }
      a[:total_questoes_ids] << q_id
      if has_res
        a[:resolvidas_ids] << q_id
        a[:acertos_ids] << q_id if res_correta
      end

      if t_id
        t = a[:topicos][t_id] ||= {
          id: t_id, name: row['topico_nome'],
          total_questoes_ids: Set.new,
          resolvidas_ids: Set.new,
          acertos_ids: Set.new
        }
        t[:total_questoes_ids] << q_id
        if has_res
          t[:resolvidas_ids] << q_id
          t[:acertos_ids] << q_id if res_correta
        end
      end
    end

    hierarchy = disciplinas_map.values.map do |d|
      {
        id: d[:id],
        name: d[:name],
        total_questoes: d[:total_questoes_ids].size,
        total_resolvidas: d[:resolvidas_ids].size,
        acertos: d[:acertos_ids].size,
        erros: d[:resolvidas_ids].size - d[:acertos_ids].size,
        assuntos: d[:assuntos].values.map do |a|
          {
            id: a[:id],
            name: a[:name],
            total_questoes: a[:total_questoes_ids].size,
            total_resolvidas: a[:resolvidas_ids].size,
            acertos: a[:acertos_ids].size,
            erros: a[:resolvidas_ids].size - a[:acertos_ids].size,
            questao_ids: a[:total_questoes_ids].to_a,
            topicos: a[:topicos].values.map do |t|
              {
                id: t[:id],
                name: t[:name],
                total_questoes: t[:total_questoes_ids].size,
                total_resolvidas: t[:resolvidas_ids].size,
                acertos: t[:acertos_ids].size,
                erros: t[:resolvidas_ids].size - t[:acertos_ids].size,
                questao_ids: t[:total_questoes_ids].to_a
              }
            end.sort_by { |t| t[:name] }
          }
        end.sort_by { |a| a[:name] }
      }
    end.sort_by { |d| d[:name] }

    [hierarchy, resolvidas_ids]
  end
end

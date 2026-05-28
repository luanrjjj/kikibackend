class AdminController < ApplicationController
  before_action :authenticate_admin!

  def refresh_stats
    RefreshAdminStatsJob.perform_async
    render json: { message: "Job de atualização de estatísticas enfileirado com sucesso!" }, status: :ok
  rescue StandardError => e
    render json: { error: "Erro ao enfileirar job", message: e.message }, status: :internal_server_error
  end

  def user_stats
    # Users per month (last 12 months) using standard SQL for PostgreSQL/SQLite
    monthly_registrations = User.where('created_at >= ?', 12.months.ago)
                                .group("DATE_TRUNC('month', created_at)")
                                .order("DATE_TRUNC('month', created_at)")
                                .count
                                .map do |date, count|
      { month: date.strftime("%b/%y"), count: count }
    end

    # Subscriber stats
    total_users = User.count
    active_subscribers = User.where(subscription_status: 'ACTIVE').count
    trial_users = User.where("trial_ends_at > ?", Time.current).count
    admin_users = User.where(admin: true).count

    render json: {
      monthly_registrations: monthly_registrations,
      stats: {
        total_users: total_users,
        active_subscribers: active_subscribers,
        trial_users: trial_users,
        admin_users: admin_users,
        subscriber_percentage: total_users > 0 ? ((active_subscribers.to_f / total_users) * 100).round(2) : 0
      }
    }
  end
end

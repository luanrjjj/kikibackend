require "test_helper"

class PastaCadernosControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get pasta_cadernos_index_url
    assert_response :success
  end

  test "should get create" do
    get pasta_cadernos_create_url
    assert_response :success
  end

  test "should get update" do
    get pasta_cadernos_update_url
    assert_response :success
  end

  test "should get destroy" do
    get pasta_cadernos_destroy_url
    assert_response :success
  end
end

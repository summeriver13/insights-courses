require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows recent courses" do
    get root_url
    assert_response :success
    assert_select "h3", text: courses(:one).title
    assert_select "h3", text: courses(:two).title
  end

  test "shows recent activities" do
    get root_url
    assert_response :success
    assert_select "strong", text: activities(:one).activity_type
  end

  test "shows the learning dashboard after login" do
    log_in_as users(:two)

    get root_url

    assert_response :success
    assert_select "h1", text: "我的学习"
    assert_select "h3", text: courses(:two).title
    assert_select "h3", text: courses(:one).title, count: 0
    assert_select "a", text: /Rails 作业/
    assert_select "h2", text: "我管理的课程"
    assert_select "a", text: /#{courses(:one).title}/
    assert_select "h2", text: "最新课程", count: 0
    assert_equal "private, no-store", response.headers["CDN-Cache-Control"]
  end

  test "shows an empty learning state but keeps managed courses for admins" do
    log_in_as users(:one)

    get root_url

    assert_response :success
    assert_select "h1", text: "我的学习"
    assert_select ".alert", text: /你还没有加入学习的课程/
    assert_select "h2", text: "我管理的课程"
    assert_select "a", text: "新建课程"
  end
end

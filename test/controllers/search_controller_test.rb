require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "searches courses and lessons" do
    get search_url(q: "正文")

    assert_response :success
    assert_select "strong", text: "第一课"
  end

  test "renders a prompt for a blank query" do
    get search_url

    assert_response :success
    assert_select "p", text: "输入关键词开始搜索。"
  end

  test "hides questions from non-managers" do
    get search_url(q: "哪个阶段")
    assert_select "strong", text: /哪个阶段先做/, count: 0

    log_in_as users(:two)
    get search_url(q: "哪个阶段")
    assert_select "strong", text: /哪个阶段先做/, count: 0
  end

  test "shows questions to course managers" do
    log_in_as users(:one)
    get search_url(q: "哪个阶段")

    assert_response :success
    assert_select "strong", text: /哪个阶段先做/
    assert_select "p", text: /分析回答 what/, count: 0
  end

  test "scopes search to a course" do
    get search_url(q: "Ruby", course_id: courses(:two).id)

    assert_response :success
    assert_select "strong", text: "Ruby Basics", count: 0
    assert_select "p", text: /没有匹配/
  end

  test "searches resources and assessments" do
    get search_url(q: "Lecture slides")
    assert_select "strong", text: /Lecture slides/

    get search_url(q: "期末考试")
    assert_select "strong", text: /期末考试/
  end
end

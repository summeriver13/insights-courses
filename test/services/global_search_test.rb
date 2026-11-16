require "test_helper"

class GlobalSearchTest < ActiveSupport::TestCase
  test "finds lessons by body" do
    results = GlobalSearch.new("正文").call

    assert_equal 1, results.lessons.total
    assert_equal lessons(:one), results.lessons.items.first
  end

  test "limits questions to course managers" do
    manager = GlobalSearch.new("哪个阶段", user: users(:one)).call
    member = GlobalSearch.new("哪个阶段", user: users(:two)).call

    assert_equal 1, manager.questions.total
    assert_equal 0, member.questions.total
  end

  test "scopes results to one course" do
    results = GlobalSearch.new("Ruby", course: courses(:two)).call

    assert_equal 0, results.courses.total
    assert_equal 0, results.assessments.total
  end

  test "returns empty results for a blank query" do
    assert_predicate GlobalSearch.new(" ").call, :empty?
  end

  test "treats wildcard characters literally" do
    lesson = lessons(:one)
    lesson.update!(body: "Progress: 50% done")

    results = GlobalSearch.new("%").call

    assert_equal 1, results.lessons.total
    assert_equal lesson, results.lessons.items.first
  end
end

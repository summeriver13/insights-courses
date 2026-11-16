require "test_helper"

class HomeDashboardTest < ActiveSupport::TestCase
  test "summarizes student courses and separates managed courses" do
    dashboard = HomeDashboard.new(users(:two))

    assert_equal [ courses(:two) ], dashboard.summaries.map(&:course)
    assert_equal [ courses(:one) ], dashboard.teaching_courses
    summary = dashboard.summaries.first
    assert_equal 0, summary.done_lessons
    assert_equal 0, summary.total_lessons
    assert_equal 0, summary.mistakes
    assert_nil summary.grade
    assert_not summary.complete?
  end

  test "lists only unsubmitted deadlines for learning courses" do
    dashboard = HomeDashboard.new(users(:two))

    assert_equal [ "Rails 作业" ], dashboard.deadlines.map(&:title)
    assert_equal 1, dashboard.pending_deadlines_count
  end

  test "hides a deadline after the student submits" do
    assessments(:two).submissions.create!(user: users(:two), body: "done")

    dashboard = HomeDashboard.new(users(:two))

    assert_empty dashboard.deadlines
    assert_equal 0, dashboard.pending_deadlines_count
  end

  test "tracks each deliverable and hides the submitted one" do
    assessment = assessments(:two)
    proposal = assessment.deliverables.create!(name: "提案", due_at: 2.days.from_now)
    assessment.deliverables.create!(name: "报告", due_at: 3.days.from_now)
    assessment.submissions.create!(user: users(:two), deliverable: proposal, body: "done")

    dashboard = HomeDashboard.new(users(:two))
    titles = dashboard.deadlines.map(&:title)

    assert_not_includes titles, "Rails 作业 · 提案"
    assert_includes titles, "Rails 作业 · 报告"
  end

  test "hides a quiz deadline after an attempt" do
    assessment = assessments(:two)
    assessment.update!(kind: "quiz", due_at: 2.days.from_now)
    courses(:two).attempts.create!(user: users(:two), assessment: assessment, taken_at: Time.current, score: 1, total: 1)

    dashboard = HomeDashboard.new(users(:two))

    assert_empty dashboard.deadlines
  end

  test "hides a group deadline after a group submission" do
    assessment = assessments(:two)
    assessment.update!(group_work: true)
    assessment.submissions.create!(user: users(:two), group: groups(:two), body: "done")

    dashboard = HomeDashboard.new(users(:two))

    assert_empty dashboard.deadlines
  end

  test "counts distinct wrong questions" do
    attempt = courses(:two).attempts.create!(user: users(:two), taken_at: Time.current, score: 0, total: 1)
    attempt.answers.create!(question: questions(:single), response: "设计", correct: false)
    attempt.answers.create!(question: questions(:single), response: "错误", correct: false)

    dashboard = HomeDashboard.new(users(:two))

    assert_equal 1, dashboard.summaries.first.mistakes
  end

  test "tracks completed lessons and the next lesson" do
    lesson = courses(:two).lessons.create!(position: 1, title: "第一课", body: "正文")
    lesson.lesson_completions.create!(user: users(:two))

    dashboard = HomeDashboard.new(users(:two))
    summary = dashboard.summaries.first

    assert_equal 1, summary.done_lessons
    assert_equal 1, summary.total_lessons
    assert_equal 0, summary.incomplete_lessons
    assert_nil summary.next_lesson
  end

  test "treats a group assessment without a group as missing" do
    group_memberships(:two).destroy!
    assessment = assessments(:two)
    assessment.update!(group_work: true)

    dashboard = HomeDashboard.new(users(:two))
    deadline = dashboard.deadlines.find { |item| item.assessment == assessment }

    assert deadline.group_missing?
  end

  test "uses the current grade only when every assessment is graded" do
    course = Course.create!(
      title: "Grade test",
      description: "Grade test",
      course_number: "GT101"
    )
    course.course_memberships.create!(user: users(:two), role: CourseMembership::STUDENT_ROLE)
    assessment = course.assessments.create!(title: "Final", kind: "exam", weight: 100)
    submission = assessment.submissions.create!(user: users(:two), body: "answer")
    submission.create_grade!(score: 80)

    dashboard = HomeDashboard.new(users(:two))
    summary = dashboard.summaries.find { |item| item.course == course }

    assert_equal 80.0, summary.grade
    assert_equal "D", summary.letter
    assert summary.complete?
    assert_equal 1, summary.graded_count
    assert_equal 1, summary.assessment_count
  end

  test "admin sees every course as managed and no learning courses" do
    dashboard = HomeDashboard.new(users(:one))

    assert_empty dashboard.summaries
    assert_equal [ courses(:one), courses(:two) ].sort_by(&:id), dashboard.teaching_courses.sort_by(&:id)
  end
end

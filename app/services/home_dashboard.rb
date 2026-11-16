class HomeDashboard
  DEADLINE_LIMIT = 5

  Deadline = Data.define(:course, :assessment, :deliverable, :due_at, :group_missing) do
    def title
      deliverable ? "#{assessment.title} · #{deliverable.name}" : assessment.title
    end

    def overdue?
      due_at < Time.current
    end

    def days_until
      (course.local_time(due_at).to_date - course.local_time(Time.current).to_date).to_i
    end

    def group_missing?
      group_missing
    end
  end

  CourseSummary = Data.define(
    :course, :done_lessons, :total_lessons, :next_lesson,
    :assessment_count, :graded_count, :grade, :letter, :mistakes
  ) do
    def incomplete_lessons
      total_lessons - done_lessons
    end

    def progress_percent
      return 0 if total_lessons.zero?

      (done_lessons * 100.0 / total_lessons).round
    end

    def complete?
      assessment_count.positive? && graded_count == assessment_count
    end
  end

  attr_reader :summaries, :deadlines, :teaching_courses, :pending_deadlines_count

  def initialize(user, now: Time.current)
    @user = user
    @now = now
    @contexts = {}
    @assessments = {}
    @group_ids = {}
    @learning_memberships = user.course_memberships
      .where(role: CourseMembership::STUDENT_ROLE)
      .includes(:course)
      .order(created_at: :desc)
    @summaries = @learning_memberships.map { |membership| build_summary(membership.course) }
    @all_deadlines = @summaries.flat_map { |summary| deadlines_for(summary.course) }
    @pending_deadlines_count = @all_deadlines.size
    @deadlines = @all_deadlines
      .sort_by { |deadline| [ deadline.due_at < @now ? 0 : 1, deadline.due_at ] }
      .first(DEADLINE_LIMIT)
    @teaching_courses = load_teaching_courses
  end

  def incomplete_lessons_count
    summaries.sum(&:incomplete_lessons)
  end

  def mistakes_count
    summaries.sum(&:mistakes)
  end

  private

  def build_summary(course)
    done, total = course.lesson_progress_for(@user)
    assessments = assessments_for(course)
    context = context_for(course)
    graded = assessments.count { |assessment| assessment.raw_score_for(@user, context).present? }
    complete = graded.positive? && graded == assessments.size
    grade = graded.positive? ? course.grade_for(@user, context) : nil
    letter = complete ? course.letter_grade(@user, context) : nil

    CourseSummary.new(
      course: course,
      done_lessons: done,
      total_lessons: total,
      next_lesson: next_lesson_for(course),
      assessment_count: assessments.size,
      graded_count: graded,
      grade: grade,
      letter: letter,
      mistakes: mistakes_for(course)
    )
  end

  def next_lesson_for(course)
    completed = completed_lesson_ids
    course.lessons.find { |lesson| !completed.include?(lesson.id) }
  end

  def completed_lesson_ids
    @completed_lesson_ids ||= @user.lesson_completions.pluck(:lesson_id)
  end

  def mistakes_for(course)
    Answer.joins(:attempt)
      .where(attempts: { course_id: course.id, user_id: @user.id }, correct: false)
      .distinct
      .count(:question_id)
  end

  def context_for(course)
    @contexts[course.id] ||= ScoreContext.new(course, [ @user ])
  end

  def assessments_for(course)
    @assessments[course.id] ||= course.assessments.includes(:deliverables).to_a
  end

  def deadlines_for(course)
    assessments = assessments_for(course)
    submitted = submitted_keys(course, assessments)
    groups = group_ids_for(course)
    context = context_for(course)

    assessments.flat_map do |assessment|
      deadline_items(assessment).filter_map do |deliverable, due_at|
        next if due_at.nil?
        next if submitted.include?([ assessment.id, deliverable&.id ])
        next if deliverable.nil? && assessment.raw_score_for(@user, context).present?

        Deadline.new(
          course: course,
          assessment: assessment,
          deliverable: deliverable,
          due_at: due_at,
          group_missing: assessment.group_work? && groups.empty?
        )
      end
    end
  end

  def deadline_items(assessment)
    return [ [ nil, assessment.due_at ] ] if assessment.deliverables.empty?

    assessment.deliverables.map do |deliverable|
      [ deliverable, deliverable.due_at || assessment.due_at ]
    end
  end

  def submitted_keys(course, assessments)
    ids = assessments.map(&:id)
    return [] if ids.empty?

    scope = Submission.where(assessment_id: ids)
    groups = group_ids_for(course)
    scope = if groups.any?
      scope.where(user_id: @user.id).or(scope.where(group_id: groups))
    else
      scope.where(user_id: @user.id)
    end
    scope.pluck(:assessment_id, :deliverable_id)
  end

  def group_ids_for(course)
    @group_ids[course.id] ||= GroupMembership.joins(:group)
      .where(groups: { course_id: course.id }, user_id: @user.id)
      .pluck(:group_id)
  end

  def load_teaching_courses
    scope = if @user.admin?
      Course.all
    else
      Course.joins(:course_memberships)
        .where(course_memberships: { user_id: @user.id, role: CourseMembership::MANAGE_ROLES })
        .distinct
    end
    learning_ids = @learning_memberships.map(&:course_id)
    scope = scope.where.not(id: learning_ids) if learning_ids.any?
    scope.order(created_at: :desc).to_a
  end
end

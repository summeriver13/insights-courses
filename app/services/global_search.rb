class GlobalSearch
  LIMIT = 20

  Group = Data.define(:items, :total)
  Result = Data.define(:courses, :lessons, :resources, :assessments, :activities, :questions) do
    def empty?
      to_h.values.all? { |group| group.total.zero? }
    end
  end

  def initialize(query, user: nil, course: nil)
    @query = query.to_s.strip
    @user = user
    @course = course
  end

  def call
    return empty_result if @query.blank?

    Result.new(
      courses: courses,
      lessons: lessons,
      resources: resources,
      assessments: assessments,
      activities: activities,
      questions: questions
    )
  end

  private

  def courses
    scope = Course.search(@query)
    scope = scope.where(id: @course.id) if @course
    group(scope.order(created_at: :desc))
  end

  def lessons
    scope = Lesson.joins(:course).where(
      "LOWER(lessons.title) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(lessons.body) LIKE LOWER(:pattern) ESCAPE '\\'",
      pattern: pattern
    )
    scope = scope.where(course_id: @course.id) if @course
    group(scope.order(:course_id, :position, :id), includes: [ :course ])
  end

  def resources
    scope = Resource.joins(:course).where(
      "LOWER(resources.name) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(resources.description) LIKE LOWER(:pattern) ESCAPE '\\'",
      pattern: pattern
    )
    scope = scope.where(course_id: @course.id) if @course
    group(scope.order(:course_id, :name), includes: [ :course ])
  end

  def assessments
    scope = Assessment.joins(:course).where(
      "LOWER(assessments.title) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(assessments.description) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(assessments.scope) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(assessments.venue) LIKE LOWER(:pattern) ESCAPE '\\'",
      pattern: pattern
    )
    scope = scope.where(course_id: @course.id) if @course
    group(scope.order(:course_id, :due_at, :id), includes: [ :course ])
  end

  def activities
    scope = Activity.joins(:course).where(
      "LOWER(activities.activity_type) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(activities.location) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(activities.description) LIKE LOWER(:pattern) ESCAPE '\\'",
      pattern: pattern
    )
    scope = scope.where(course_id: @course.id) if @course
    group(scope.order(:course_id, :start_time), includes: [ :course ])
  end

  def questions
    return group(Question.none) if @user.nil?

    scope = Question.joins(:course).where(course_id: manageable_courses.select(:id)).where(
      "LOWER(questions.stem) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(questions.topic) LIKE LOWER(:pattern) ESCAPE '\\' OR LOWER(questions.explanation) LIKE LOWER(:pattern) ESCAPE '\\'",
      pattern: pattern
    )
    scope = scope.where(course_id: @course.id) if @course
    group(scope.order(:course_id, :id), includes: [ :course, :lesson ])
  end

  def manageable_courses
    return Course.all if @user.admin?

    Course.where(id: CourseMembership.where(user_id: @user.id, role: CourseMembership::MANAGE_ROLES).select(:course_id))
  end

  def group(scope, includes: [])
    total = scope.count
    items = includes.any? ? scope.includes(*includes).limit(LIMIT).to_a : scope.limit(LIMIT).to_a
    Group.new(items: items, total: total)
  end

  def pattern
    @pattern ||= "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
  end

  def empty_result
    empty = Group.new(items: [], total: 0)
    Result.new(courses: empty, lessons: empty, resources: empty, assessments: empty, activities: empty, questions: empty)
  end
end

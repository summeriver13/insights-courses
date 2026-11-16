class HomeController < ApplicationController
  RECENT_COURSES_LIMIT = 3
  RECENT_ACTIVITIES_LIMIT = 5

  def index
    if logged_in?
      @dashboard = HomeDashboard.new(current_user)
    else
      @courses = Course.order(created_at: :desc).limit(RECENT_COURSES_LIMIT)
      @activities = Activity.includes(:course).order(start_time: :desc).limit(RECENT_ACTIVITIES_LIMIT)
    end
  end
end

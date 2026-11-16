class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @course = Course.find(params[:course_id]) if params[:course_id].present?
    @results = GlobalSearch.new(@query, user: current_user, course: @course).call
  end
end

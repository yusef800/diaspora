
# frozen_string_literal: true

module Admin
  # class for handling pod specific actions
  class PodsController < AdminController
    respond_to :html, :json, :mobile

    # action for displaying a list of pods
    def index
      # collects pod data and stores in object
      pods_json = PodPresenter.as_collection(Pod.all)

      # handles responses for different formats(html, mobile, json)
      respond_with do |format|
        format.html do
          gon.preloads[:pods] = pods_json
          gon.unchecked_count = Pod.unchecked.count
          gon.version_failed_count = Pod.version_failed.count
          gon.error_count = Pod.check_failed.count
          gon.active_count = Pod.active.count
          gon.total_count = Pod.count
          render "admins/pods"
        end
        format.mobile { render "admins/pods" }
        format.json { render json: pods_json }
      end
    end

    # action to recheck the connection of a specific pod
    def recheck
      # finds the pod by its ID
      pod = Pod.find(params[:pod_id])
      pod.test_connection! # tests pod connection

      # returns response for different formats(html, json)
      respond_with do |format|
        format.html { redirect_to admin_pods_path }
        format.json { render json: PodPresenter.new(pod).as_json }
      end
    end
  end
end

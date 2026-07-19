module Api
  module V1
    class AvatarsController < BaseController
      before_action :set_user

      # PUT /api/v1/users/:id/avatar
      # Proxied: multipart file in :avatar. Direct-upload: :signed_id from presign step.
      def update
        authorize @user, :update?
        if params[:signed_id].present?
          @user.avatar.attach(params[:signed_id])
        elsif params[:avatar].present?
          @user.avatar.attach(params[:avatar])
        else
          return render_error(message: "No file provided", error_code: "no_file",
                              errors: [ { field: "avatar", message: "is required" } ],
                              status: :bad_request)
        end
        @user.save!   # active_storage_validations run here; RecordInvalid -> envelope
        render_success(UserSerializer.one(@user), message: "Avatar updated")
      end

      # DELETE /api/v1/users/:id/avatar
      def destroy
        authorize @user, :update?
        @user.avatar.purge_later
        render_success(nil, message: "Avatar removed")
      end

      # POST /api/v1/users/:id/avatar_presign  (direct-to-S3: client uploads to the
      # returned URL, then calls PUT avatar with the signed_id)
      def presign
        authorize @user, :update?
        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: params.require(:filename),
          byte_size: params.require(:byte_size),
          checksum: params.require(:checksum),
          content_type: params.require(:content_type)
        )
        render_success({
          signed_id: blob.signed_id,
          direct_upload: {
            url: blob.service_url_for_direct_upload,
            headers: blob.service_headers_for_direct_upload
          }
        }, message: "Presigned upload URL created")
      end

      private

      def set_user = @user = User.kept.find(params[:id])
    end
  end
end

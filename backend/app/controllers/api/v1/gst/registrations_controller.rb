module Api
  module V1
    module Gst
      class RegistrationsController < Api::V1::BaseController
        before_action :require_organization!

        # GET /api/v1/gst/registrations
        def index
          authorize current_organization, :manage_gst_registrations?
          policy_scope(Branch)
          
          branches = current_organization.branches.active.includes(:organization).group_by(&:state_code)
          registrations = current_organization.gst_state_registrations
          
          data = {}
          registrations.each do |state_code, reg|
            branches_in_state = branches[state_code]&.map(&:name) || []
            data[state_code] = {
              gstin: reg["gstin"],
              username: reg["username"],
              password: reg["password"],
              branch_count: branches_in_state.count,
              branches: branches_in_state,
              configured_at: reg["configured_at"],
              configured_by_id: reg["configured_by_id"]
            }
          end
          
          render json: { data: data }
        end

        # POST /api/v1/gst/registrations
        def create
          authorize current_organization, :manage_gst_registrations?
          
          state_code = params[:state_code]
          gstin = params[:gstin]
          username = params[:username]
          password = params[:password]
          
          unless state_code.present? && gstin.present?
            return render json: { 
              errors: ["State code and GSTIN are required"] 
            }, status: :unprocessable_entity
          end
          
          unless username.present?
            return render json: { 
              errors: ["State GST username is required"] 
            }, status: :unprocessable_entity
          end
          
          # Validate GSTIN format
          unless gstin.match?(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)
            return render json: { 
              errors: ["Invalid GSTIN format"] 
            }, status: :unprocessable_entity
          end
          
          # Validate state code matches GSTIN
          gstin_state = gstin[0..1]
          unless state_code_matches?(gstin_state, state_code)
            return render json: { 
              errors: ["GSTIN state code (#{get_state_name(gstin_state)}) must match selected state (#{get_state_name(state_code)})"] 
            }, status: :unprocessable_entity
          end
          
          # Update organization settings
          registrations = current_organization.gst_state_registrations.dup
          existing_reg = registrations[state_code] || {}
          
          # Only update password if provided (allows keeping existing password on edit)
          updated_password = password.present? ? password : existing_reg["password"]
          
          registrations[state_code] = {
            "gstin" => gstin,
            "username" => username,
            "password" => updated_password,
            "configured_at" => Time.current.iso8601,
            "configured_by_id" => current_user.id
          }
          
          if current_organization.update(settings: current_organization.settings.merge({
            "gst_state_registrations" => registrations
          }))
            render json: { 
              data: { 
                success: true, 
                state_code: state_code, 
                gstin: gstin 
              } 
            }
          else
            render json: { 
              errors: current_organization.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/gst/registrations/:state_code
        def destroy
          authorize current_organization, :manage_gst_registrations?
          
          state_code = params[:id]
          registrations = current_organization.gst_state_registrations.dup
          registrations.delete(state_code)
          
          if current_organization.update(settings: current_organization.settings.merge({
            "gst_state_registrations" => registrations
          }))
            render json: { data: { success: true } }
          else
            render json: { 
              errors: current_organization.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end

        private

        def state_code_to_abbr
          {
            "01" => "AN", "02" => "AP", "03" => "AR", "04" => "AS",
            "05" => "BR", "06" => "CG", "07" => "CH", "08" => "CT",
            "09" => "DL", "10" => "DN", "11" => "GA", "12" => "GJ",
            "13" => "HR", "14" => "HP", "15" => "JK", "16" => "JH",
            "17" => "KA", "18" => "KL", "19" => "LA", "20" => "LD",
            "21" => "MP", "22" => "MH", "23" => "MN", "24" => "ML",
            "25" => "MZ", "26" => "OD", "27" => "PD", "28" => "PB",
            "29" => "RJ", "30" => "SK", "31" => "TN", "32" => "TR",
            "33" => "TS", "34" => "UK", "35" => "UP", "36" => "UT",
            "37" => "WB"
          }
        end

        def get_state_name(code)
          state_code_to_abbr[code] || code
        end

        def state_code_matches?(gstin_state, declared_state)
          expected_state = state_code_to_abbr[gstin_state]
          expected_state == declared_state
        end
      end
    end
  end
end

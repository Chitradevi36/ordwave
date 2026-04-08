module Api
  module V1
    module Gst
      class BranchOverridesController < Api::V1::BaseController
        before_action :require_organization!

        # GET /api/v1/gst/branch_overrides
        def index
          authorize current_organization, :manage_gst_registrations?
          policy_scope(Branch)
          
          branches = current_organization.branches.active.includes(:organization)
          
          data = branches.map do |branch|
            state_gstin = current_organization.gst_for_state(branch.state_code)
            override_gstin = branch.gst_override_gstin
            
            {
              branch_id: branch.id,
              branch_name: branch.name,
              state_code: branch.state_code,
              state_gstin: state_gstin,
              override_gstin: override_gstin,
              effective_gstin: branch.effective_gstin,
              using_state_gstin: branch.using_state_gstin?,
              using_override_gstin: branch.using_override_gstin?,
              using_org_gstin: branch.using_org_gstin?
            }
          end
          
          render json: { data: data }
        end

        # POST /api/v1/gst/branch_overrides
        def create
          branch = current_organization.branches.find(params[:branch_id])
          authorize branch, :update_gst_registration?
          
          gstin = params[:branch_gstin]
          
          unless gstin.present?
            return render json: { 
              errors: ["GSTIN is required"] 
            }, status: :unprocessable_entity
          end
          
          # Validate GSTIN format
          unless gstin.match?(/^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/)
            return render json: { 
              errors: ["Invalid GSTIN format"] 
            }, status: :unprocessable_entity
          end
          
          # Validate state code matches
          gstin_state = gstin[0..1]
          unless state_code_matches?(gstin_state, branch.state_code)
            return render json: { 
              errors: ["GSTIN state code (#{get_state_name(gstin_state)}) must match branch state (#{get_state_name(branch.state_code)})"] 
            }, status: :unprocessable_entity
          end
          
          # Update branch settings
          new_settings = branch.settings.dup
          new_settings["gst_override"] = {
            "branch_gstin" => gstin,
            "configured_at" => Time.current.iso8601,
            "configured_by_id" => current_user.id
          }
          
          if branch.update(settings: new_settings)
            render json: { 
              data: { 
                success: true, 
                branch_id: branch.id,
                branch_gstin: gstin 
              } 
            }
          else
            render json: { 
              errors: branch.errors.full_messages 
            }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/gst/branch_overrides/:branch_id
        def destroy
          branch = current_organization.branches.find(params[:id])
          authorize branch, :update_gst_registration?
          
          new_settings = branch.settings.dup
          new_settings.delete("gst_override")
          
          if branch.update(settings: new_settings)
            render json: { data: { success: true } }
          else
            render json: { 
              errors: branch.errors.full_messages 
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

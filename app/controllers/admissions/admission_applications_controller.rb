# Copyright (c) Universidade Federal Fluminense (UFF).
# This file is part of SAPOS. Please, consult the license terms in the LICENSE file.

# frozen_string_literal: true

class Admissions::AdmissionApplicationsController < ApplicationController
  authorize_resource
  before_action :update_table_config

  I18N_BASE = "activerecord.attributes.admissions/admission_application"

  active_scaffold "Admissions::AdmissionApplication" do |config|
    config.list.columns = [
      :admission_process, :token, :name, :email, :submission_time,
      :letter_requests, :filled_form,
      :admission_phase, :status,
    ]
    config.show.columns = [
      :admission_process, :token, :name, :email,
      :admission_phase, :status,
      :filled_form, :letter_requests,
      :results, :evaluations, :rankings
    ]

    config.list.sorting = { admission_process: "DESC", name: "ASC" }

    config.delete.link.weight = -1
    config.delete.link.html_options = { class: "advanced-config-item" }

    config.action_links.add "cancel",
      label: "<i title='#{
        I18n.t "active_scaffold.admissions/admission_application.cancel.title"
      }' class='fa fa-remove'></i>".html_safe,
      type: :member,
      keep_open: false,
      position: false,
      crud_type: :update,
      method: :put,
      html_options: { class: "advanced-config-item" },
      refresh_list: true,
      ignore_method: :cancel_ignore?,
      security_method: :cancel_authorized?,
      confirm: I18n.t(
        "active_scaffold.admissions/admission_application.cancel.confirm"
      )

    config.action_links.add "undo_consolidation",
      label: "<i title='#{
        I18n.t "active_scaffold.admissions/admission_application.undo_consolidation.title"
      }' class='fa fa-undo'></i>".html_safe,
      type: :member,
      keep_open: false,
      position: false,
      crud_type: :update,
      method: :put,
      html_options: { class: "advanced-config-item" },
      refresh_list: true,
      ignore_method: :undo_consolidation_ignore?,
      security_method: :undo_consolidation_authorized?,
      confirm: I18n.t(
        "active_scaffold.admissions/admission_application.undo_consolidation.confirm"
      )

    config.action_links.add "edit_override",
      label: "<i title='#{
        I18n.t "active_scaffold.admissions/admission_application.edit_override.title"
      }' class='fa fa-pencil-square edit-override'></i>".html_safe,
      type: :member,
      ignore_method: :override_ignore?,
      security_method: :override_authorized?,
      html_options: { class: "advanced-config-item" },
      action: :edit,
      parameters: {
        override: true
      }

    config.action_links.add "configuration",
      label: "<i title='#{
        I18n.t "active_scaffold.admissions/admission_application.configuration.title"
      }' class='fa fa-cog advanced-config'></i>".html_safe,
      type: :member,
      security_method: :configuration_authorized?,
      ignore_method: :configuration_ignore?,
      position: false

    config.action_links.add "configure_all",
      label: I18n.t("active_scaffold.admissions/admission_application.configure_all.title"),
      type: :collection,
      security_method: :configure_all_authorized?,
      ignore_method: :configure_all_ignore?,
      position: false

    config.columns.add :is_filled
    config.columns.add :pendency
    config.columns.add :custom_forms

    config.columns[:admission_process].search_ui = :record_select
    config.columns[:is_filled].search_sql = ""
    config.columns[:is_filled].search_ui = :select
    config.columns[:is_filled].options = {
      options: I18n.t("#{I18N_BASE}.is_filled_options").values,
      include_blank: I18n.t("active_scaffold._select_")
    }
    config.columns[:pendency].search_sql = ""
    config.columns[:pendency].search_ui = :select
    config.columns[:pendency].options = {
      options: I18n.t("#{I18N_BASE}.pendency_options").values,
      include_blank: I18n.t("active_scaffold._select_")
    }
    config.columns[:admission_phase].actions_for_association_links = [:show]
    config.columns[:admission_phase].search_ui = :record_select
    config.columns[:admission_phase].sort_by sql: [:admission_phase_id]

    config.columns[:status].search_sql = ""
    config.columns[:status].search_ui = :select

    config.update.columns = [:custom_forms]
    config.update.multipart = true


    config.actions.swap :search, :field_search
    config.field_search.columns = [
      :admission_process,
      :token,
      :name,
      :email,
      :is_filled,
      :pendency,
      :admission_phase,
      :status
    ]
    config.actions.exclude :deleted_records, :create
  end

  def update_table_config
    if current_user
      active_scaffold_config.columns[:status].sort_by sql: Arel.sql("
        CASE
          WHEN `admission_applications`.`status` IS NOT NULL THEN `admission_applications`.`status`
          WHEN `admission_applications`.`id` IN (
            SELECT `admission_application_id`
            FROM `admission_pendencies`
            WHERE `admission_pendencies`.`status`=\"#{Admissions::AdmissionPendency::PENDENT}\"
            AND (
              (
                `admission_pendencies`.`admission_phase_id` IS NULL AND
                `admission_applications`.`admission_phase_id` IS NULL
              ) OR (
                `admission_pendencies`.`admission_phase_id` = `admission_applications`.`admission_phase_id`
              )
            )
            AND `admission_pendencies`.`user_id`=#{current_user.id}
          ) THEN \"#{Admissions::AdmissionPendency::PENDENT}\"
          ELSE \"-\"
        END
      ")
    else
      active_scaffold_config.columns[:status].sort_by sql: "status"
    end
  end

  def self.condition_for_is_filled_column(column, value, like_pattern)
    filled_form = "
      select `ff`.`id` from filled_forms `ff`
      where `ff`.`is_filled` = 1
    "
    case value
    when I18n.t("#{I18N_BASE}.is_filled_options.true")
      ["`admission_applications`.`filled_form_id` in (#{filled_form})"]
    when I18n.t("#{I18N_BASE}.is_filled_options.false")
      ["`admission_applications`.`filled_form_id` not in (#{filled_form})"]
    else
      ""
    end
  end

  def self.condition_for_pendency_column(column, value, like_pattern)
    candidate_arel = Admissions::AdmissionApplication.arel_table
    pendency_arel = Admissions::AdmissionPendency.arel_table
    pendencies_query = pendency_arel.where(
      pendency_arel[:status].eq(Admissions::AdmissionPendency::PENDENT)
      .and(pendency_arel[:admission_phase_id].eq(candidate_arel[:admission_phase_id]))
    ).project(pendency_arel[:admission_application_id])
    case value
    when I18n.t("#{I18N_BASE}.pendency_options.true")
      [candidate_arel[:id].in(pendencies_query).to_sql]
    when I18n.t("#{I18N_BASE}.pendency_options.false")
      [candidate_arel[:id].not_in(pendencies_query).to_sql]
    else
      ""
    end
  end

  def self.condition_for_status_column(column, value, like_pattern)
    candidate_arel = Admissions::AdmissionApplication.arel_table
    return "" if value.blank?
    if value.to_i.to_s == value
      value = value.to_i
      user_id = value.abs
      pendency_arel = Admissions::AdmissionPendency.arel_table
      pendencies_query = pendency_arel.where(
        pendency_arel[:status].eq(Admissions::AdmissionPendency::PENDENT)
        .and(pendency_arel[:admission_phase_id].eq(candidate_arel[:admission_phase_id]))
        .and(pendency_arel[:user_id].eq(user_id))
      ).project(pendency_arel[:admission_application_id])
      result = candidate_arel[:status].eq(nil)
      if value < 0
        [result.and(candidate_arel[:id].not_in(pendencies_query)).to_sql]
      else
        [result.and(candidate_arel[:id].in(pendencies_query)).to_sql]
      end
    else
      [candidate_arel[:status].eq(value).to_sql]
    end
  end

  def update_authorized?(record = nil, column = nil)
    return super if record.nil?
    phase = record.admission_phase
    return false if phase.nil?
    return false if Admissions::AdmissionApplication::END_OF_PHASE_STATUSES.include?(
      record.status
    )

    phase.admission_committees.any? do |committee|
      if record.satisfies_condition(committee.form_condition)
        committee.members.where(user_id: current_user.id).first.present?
      end
    end && super
  end

  def cancel_ignore?(record)
    (
      (record.status == Admissions::AdmissionApplication::CANCELED) ||
      cannot?(:cancel, record)
    )
  end

  def cancel_authorized?(record = nil, column = nil)
    can?(:cancel, record)
  end

  def cancel
    raise CanCan::AccessDenied.new if cannot? :cancel, Admissions::AdmissionApplication
    process_action_link_action(:cancel) do |record|
      next if cancel_ignore?(record)
      record.update!(
        status: Admissions::AdmissionApplication::CANCELED,
        status_message: nil,
      )
      self.successful = true
      flash[:info] = I18n.t("active_scaffold.admissions/admission_application.cancel.success")
    end
  end

  def undo_consolidation_ignore?(record)
    eop = Admissions::AdmissionApplication::END_OF_PHASE_STATUSES
    (record.admission_phase_id.nil? && !eop.include?(record.status)) ||
      cannot?(:undo_consolidation, record) ||
      !record.admission_process.staff_can_undo
  end

  def undo_consolidation_authorized?(record = nil, column = nil)
    can?(:undo_consolidation, record)
  end

  def undo_consolidation
    raise CanCan::AccessDenied.new if cannot? :undo_consolidation, Admissions::AdmissionApplication
    process_action_link_action(:undo_consolidation) do |record|
      next if undo_consolidation_ignore?(record)
      eop = Admissions::AdmissionApplication::END_OF_PHASE_STATUSES
      if eop.include?(record.status)
        set_phase_id = record.admission_phase_id
      else
        phases = [nil] + record.admission_process.phases.order(:order).map do |p|
          p.admission_phase.id
        end
        index = phases.find_index(record.admission_phase_id)
        set_phase_id = phases[index - 1]
      end
      record.pendencies.where(
        status: Admissions::AdmissionPendency::PENDENT,
        admission_phase_id: record.admission_phase_id
      ).delete_all
      record.update!(
        admission_phase_id: set_phase_id,
        status: nil,
        status_message: nil,
      )
      if set_phase_id.present?
        record.results.where(
          mode: Admissions::AdmissionPhaseResult::CONSOLIDATION,
          admission_phase_id: set_phase_id
        ).delete_all
        prev_phase = Admissions::AdmissionPhase.find(set_phase_id)
        prev_phase.update_pendencies
        prev_phase_name = prev_phase.name
      else
        prev_phase_name = "Candidatura"
      end
      self.successful = true
      flash[:info] = I18n.t("active_scaffold.admissions/admission_application.undo_consolidation.success", name: prev_phase_name)
    end
  end

  def override_authorized?(record = nil, column = nil)
    return super if record.nil?
    can?(:override, record) && record.admission_process.staff_can_edit
  end

  def override_ignore?(record)
    cannot?(:override, record) || !record.admission_process.staff_can_edit
  end

  def configuration_ignore?(record)
    !(
      !cannot?(:destroy, record) ||
      !cancel_ignore?(record) ||
      !undo_consolidation_ignore?(record) ||
      !override_ignore?(record)
    )
  end

  def configuration_authorized?(record = nil, column = nil)
    can?(:destroy, record) ||
    cancel_authorized?(record) ||
    undo_consolidation_authorized?(record) ||
    override_authorized?(record)
  end

  def configuration
    @record = find_if_allowed(params[:id], :read)
  end

  def configure_all_ignore?
    !(
      !cannot?(:destroy, Admissions::AdmissionApplication) ||
      !cannot?(:cancel, Admissions::AdmissionApplication) ||
      !cannot?(:undo, Admissions::AdmissionApplication) ||
      !cannot?(:override, Admissions::AdmissionApplication)
    )
  end

  def configure_all_authorized?(record = nil, column = nil)
    can?(:destroy, record || Admissions::AdmissionApplication) ||
    can?(:cancel, record || Admissions::AdmissionApplication) ||
    can?(:undo, record || Admissions::AdmissionApplication) ||
    can?(:override, record || Admissions::AdmissionApplication)
  end

  def configure_all
    respond_to_action(:configure_all)
  end

  protected
    def before_update_save(record)
      record.filled_form.prepare_missing_fields
      phase = record.admission_phase
      record.assign_attributes(admission_application_params)
      record.letter_requests.each do |letter_request|
        letter_request.filled_form.sync_fields_after(letter_request)
      end
      if phase.present?
        phase_forms = phase.prepare_application_forms(record, current_user, false)
        phase_forms.each do |phase_form|
          phase_form[:was_filled] = phase_form[:object].filled_form.is_filled
          phase_form[:object].filled_form.is_filled = true
        end
      else
        phase_forms = []
      end
      record.filled_form.sync_fields_after(record)
      was_filled = record.filled_form.is_filled
      record.filled_form.is_filled = true
      if record.valid?
        phase_forms.each do |phase_form|
          pendency_success = phase_form[:pendency_success]
          if pendency_success.present?
            Admissions::AdmissionPendency.where(pendency_success).update_all(
              status: Admissions::AdmissionPendency::OK
            )
          end
        end
      else
        record.filled_form.is_filled = was_filled
        phase_forms.each do |phase_form|
          phase_form[:object].filled_form.is_filled = phase_form[:was_filled]
        end
      end
    end

    def admission_application_params
      params.require(:record).permit(
        :name, :email,
        filled_form_attributes:
          Admissions::FilledFormsController.filled_form_params_definition,
        letter_requests_attributes: [
          :id, :email, :name, :telephone,
          :_destroy,
          filled_form_attributes:
            Admissions::FilledFormsController.filled_form_params_definition,
        ],
        results_attributes: [
          :id, :mode, :admission_phase_id,
          filled_form_attributes:
            Admissions::FilledFormsController.filled_form_params_definition,
        ],
        evaluations_attributes: [
          :id, :user_id, :admission_phase_id,
          filled_form_attributes:
            Admissions::FilledFormsController.filled_form_params_definition,
        ]
      )
    end

    def undo_consolidation_respond_to_html
      return_to_main
    end

    def undo_consolidation_respond_to_js
      do_refresh_list if !render_parent?
      @popstate = true
      render(action: "on_undo_consolidation")
    end

    def undo_consolidation_respond_on_iframe
      do_refresh_list if !render_parent?
      responds_to_parent do
        render action: "on_undo_consolidation", formats: [:js], layout: false
      end
    end

    def cancel_respond_to_html
      return_to_main
    end

    def cancel_respond_to_js
      do_refresh_list if !render_parent?
      @popstate = true
      render(action: "on_cancel")
    end

    def cancel_respond_on_iframe
      do_refresh_list if !render_parent?
      responds_to_parent do
        render action: "on_cancel", formats: [:js], layout: false
      end
    end

    def configure_all_respond_to_js
      do_refresh_list if !render_parent?
      @popstate = true
      render(action: "configure_all")
    end
end

/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { DialogPreviewController } from '../dialog/preview.controller';
import { TimezoneService } from 'core-app/core/datetime/timezone.service';

export default class PreviewController extends DialogPreviewController {
  private timezoneService:TimezoneService;
  private highlightedField:HTMLInputElement|null = null;

  // The field values currently used by the controller
  private currentIgnoreNonWorkingDays:boolean = false;
  private currentStartDate:Date|null = null;
  private currentDueDate:Date|null = null;
  private currentDuration:number|null = null;

  private isMilestone:boolean = true;

  private handleFlatpickrDatesChangedBound = this.handleFlatpickrDatesChanged.bind(this);

  async connect() {
    this.readCurrentValues();
    super.connect();

    const context = await window.OpenProject.getPluginContext();
    this.timezoneService = context.services.timezone;

    document.addEventListener('date-picker:flatpickr-dates-changed', this.handleFlatpickrDatesChangedBound);
  }

  disconnect() {
    document.removeEventListener('date-picker:flatpickr-dates-changed', this.handleFlatpickrDatesChangedBound);
    super.disconnect();
  }

  private get dueDateField():HTMLInputElement {
    return document.getElementsByName('work_package[due_date]')[0] as HTMLInputElement;
  }

  private get startDateField():HTMLInputElement {
    return document.getElementsByName('work_package[start_date]')[0] as HTMLInputElement;
  }

  private get durationField():HTMLInputElement {
    return document.getElementsByName('work_package[duration]')[0] as HTMLInputElement;
  }

  handleFlatpickrDatesChanged(event:CustomEvent<{ dates:Date[] }>) {
    const dates = event.detail.dates;
    let fieldUpdatedWithUserValue:HTMLInputElement|null = null;

    if (this.isMilestone) {
      this.currentStartDate = dates[0];
      this.setStartDateFieldValue(dates[0]);
    } else {
      const selectedDate:Date = this.lastClickedDate(dates) || dates[0];
      let dateFieldToChange = this.dateFieldToChange();
      this.swapDateFieldsIfNeeded(selectedDate, dateFieldToChange);
      dateFieldToChange = this.dateFieldToChange();
      if (dateFieldToChange === this.startDateField) {
        this.changeStartDate(selectedDate);
      } else {
        this.changeDueDate(selectedDate);
      }
      fieldUpdatedWithUserValue = dateFieldToChange;
    }
    this.updateFlatpickrCalendar();
    if (fieldUpdatedWithUserValue) {
      this.triggerImmediatePreview(fieldUpdatedWithUserValue);
    }
  }

  dateFieldToChange():HTMLInputElement {
    if (this.isMilestone) {
      return this.startDateField;
    }

    let dateFieldToChange:HTMLInputElement;
    if (this.highlightedField === this.dueDateField
        || (this.highlightedField === this.durationField
            && this.currentStartDate !== null
            && this.currentDueDate === null)) {
      dateFieldToChange = this.dueDateField;
    } else {
      dateFieldToChange = this.startDateField;
    }
    return dateFieldToChange;
  }

  swapDateFieldsIfNeeded(selectedDate:Date, dateFieldToChange:HTMLInputElement) {
    // It needs to be swapped if the other field is set, the field to change is
    // unset, and setting it would make start and end be in the wrong order.
    if (
      dateFieldToChange === this.dueDateField
        && this.currentStartDate !== null
        && this.currentDueDate === null
        && selectedDate < this.currentStartDate
    ) {
      this.currentDueDate = this.currentStartDate;
      this.setDueDateFieldValue(this.currentDueDate);
      this.doMarkFieldAsTouched('due_date');
      this.currentStartDate = null;
      this.highlightField(this.startDateField);
    } else if (
      dateFieldToChange === this.startDateField
        && this.currentStartDate === null
        && this.currentDueDate !== null
        && selectedDate > this.currentDueDate
    ) {
      this.currentStartDate = this.currentDueDate;
      this.setStartDateFieldValue(this.currentStartDate);
      this.doMarkFieldAsTouched('start_date');
      this.currentDueDate = null;
      this.highlightField(this.dueDateField);
    }
  }

  changeStartDate(selectedDate:Date) {
    if (this.currentDueDate && this.currentDueDate < selectedDate) {
      // if selectedDate is after due date, due date and duration are cleared first.
      this.currentDueDate = null;
      this.currentDuration = null;
      this.setDueDateFieldValue(this.currentDueDate);
      this.setDurationFieldValue(this.currentDuration);
      this.doMarkFieldAsTouched('due_date');
    }
    this.currentStartDate = selectedDate;
    this.setStartDateFieldValue(this.currentStartDate);
    this.doMarkFieldAsTouched('start_date');
    this.highlightField(this.dueDateField);
    this.keepFieldValueWithPriority('start_date', 'due_date', 'duration');
  }

  changeDueDate(selectedDate:Date) {
    // if selectedDate is before start date, start date and duration are cleared first.
    if (this.currentStartDate && this.currentStartDate > selectedDate) {
      this.currentStartDate = null;
      this.currentDuration = null;
      this.setStartDateFieldValue(this.currentStartDate);
      this.setDurationFieldValue(this.currentDuration);
      this.doMarkFieldAsTouched('start_date');
    }
    this.currentDueDate = selectedDate;
    this.setDueDateFieldValue(this.currentDueDate);
    this.doMarkFieldAsTouched('due_date');
    this.highlightField(this.startDateField);
    this.keepFieldValueWithPriority('start_date', 'due_date', 'duration');
  }

  private updateFlatpickrCalendar() {
    const dates:Date[] = _.compact([this.currentStartDate, this.currentDueDate]);
    const ignoreNonWorkingDays = this.currentIgnoreNonWorkingDays;
    const mode = this.mode();

    document.dispatchEvent(
      new CustomEvent('date-picker:flatpickr-set-values', {
        detail: {
          dates,
          ignoreNonWorkingDays,
          mode,
        },
      }),
    );
  }

  private lastClickedDate(changedDates:Date[]):Date|null {
    const flatPickrDates = changedDates.map((date) => this.timezoneService.formattedISODate(date));
    if (flatPickrDates.length === 1) {
      return this.toDate(flatPickrDates[0]);
    }

    const fieldDates = _.compact([this.currentStartDate, this.currentDueDate])
                        .map((date) => this.timezoneService.formattedISODate(date));
    const diff = _.difference(flatPickrDates, fieldDates);
    return this.toDate(diff[0]);
  }

  setStartDateFieldValue(date:Date|null) {
    const field = document.getElementById('work_package_start_date') as HTMLInputElement;
    if (field) {
      field.value = this.datetoIso(date);
    }
  }

  setDueDateFieldValue(date:Date|null) {
    const field = document.getElementById('work_package_due_date') as HTMLInputElement;
    if (field) {
      field.value = this.datetoIso(date);
    }
  }

  setDurationFieldValue(duration:number|null) {
    const field = document.getElementById('work_package_duration') as HTMLInputElement;
    if (field) {
      field.value = duration?.toString() ?? '';
    }
  }

  doMarkFieldAsTouched(fieldName:string) {
    super.doMarkFieldAsTouched(fieldName);

    this.keepFieldValueWithPriority('start_date', 'due_date', 'duration');
  }

  setIgnoreNonWorkingDays(event:{ target:HTMLInputElement }) {
    this.currentIgnoreNonWorkingDays = !event.target.checked;
    this.updateFlatpickrCalendar();
  }

  // Ensures that on create forms, there is an "id" for the un-persisted
  // work package when sending requests to the edit action for previews.
  ensureValidPathname(formAction:string):string {
    const wpPath = new URL(formAction);

    if (wpPath.pathname.endsWith('/work_packages/datepicker_dialog_content')) {
      // Replace /work_packages/date_picker with /work_packages/new/date_picker
      wpPath.pathname = wpPath.pathname.replace('/work_packages/datepicker_dialog_content', '/work_packages/new/datepicker_dialog_content');
    }

    return wpPath.toString();
  }

  ensureValidWpAction(wpPath:string):string {
    return wpPath.endsWith('/work_packages/new/datepicker_dialog_content') ? 'new' : 'edit';
  }

  afterRendering() {
    this.readCurrentValues();
    this.updateFlatpickrCalendar();
  }

  readCurrentValues() {
    this.fieldInputTargets.forEach((inputField) => {
      if (inputField.name === 'work_package[ignore_non_working_days]') {
        // field is "Working days only",  but has the name "work_package[ignore_non_working_days]" for form submission.
        // Submits "0" if checked, and "1" if not checked thanks to a hidden field with same name.
        this.currentIgnoreNonWorkingDays = !inputField.checked;
      } else if (inputField.name === 'work_package[start_date]') {
        this.currentStartDate = this.toDate(inputField.value);
      } else if (inputField.name === 'work_package[due_date]') {
        this.currentDueDate = this.toDate(inputField.value);
        this.isMilestone = false;
      } else if (inputField.name === 'work_package[duration]') {
        this.currentDuration = this.toDuration(inputField.value);
      }

      if (inputField.classList.contains('op-datepicker-modal--date-field_current')) {
        this.highlightedField = inputField;
      }
    });
  }

  // called from inputs defined in the date_picker/date_form.rb
  onHighlightField(e:Event) {
    const fieldToHighlight = e.target as HTMLInputElement;
    if (fieldToHighlight) {
      this.highlightField(fieldToHighlight);
      // Datepicker can need an update when the focused field changes. This
      // allows to switch between single and range mode in certain edge cases.
      this.updateFlatpickrCalendar();
    }
  }

  highlightField(newHighlightedField:HTMLInputElement) {
    this.highlightedField = newHighlightedField;
    Array.from(document.getElementsByClassName('op-datepicker-modal--date-field_current')).forEach(
      (el) => {
        el.classList.remove('op-datepicker-modal--date-field_current');
        el.removeAttribute('data-qa-highlighted');
      },
    );

    this.highlightedField.classList.add('op-datepicker-modal--date-field_current');
    this.highlightedField.dataset.qaHighlighted = 'true';
  }

  private mode():'single'|'range' {
    if (this.isMilestone) {
      return 'single';
    }

    // This is a very special case in which only one date is set, and we want to
    // modify exactly that date again because it is highlighted. Then it does
    // not make sense to display a range as we are only changing one date.
    if ((this.highlightedField?.name === 'work_package[start_date]' && this.currentStartDate && !this.currentDueDate)
      || (this.highlightedField?.name === 'work_package[due_date]' && !this.currentStartDate && this.currentDueDate)) {
      return 'single';
    }

    return 'range';
  }

  setTodayForField(event:unknown) {
    (event as Event).preventDefault();

    const targetFieldID = (event as { params:{ fieldReference:string } }).params.fieldReference;
    if (targetFieldID) {
      const inputField = document.getElementById(targetFieldID);
      if (inputField) {
        (inputField as HTMLInputElement).value = this.timezoneService.formattedISODate(Date.now());
        inputField.dispatchEvent(new Event('input'));
      }
    }
  }

  private datetoIso(date:Date|null):string {
    if (date) {
      return this.timezoneService.formattedISODate(date);
    }
    return '';
  }

  private toDate(date:string|null):Date|null {
    if (date) {
      return new Date(date);
    }
    return null;
  }

  private toDuration(duration:string|null):number|null {
    if (duration) {
      return parseInt(duration, 10);
    }
    return null;
  }
}

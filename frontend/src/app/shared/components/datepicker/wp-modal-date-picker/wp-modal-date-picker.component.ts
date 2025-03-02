//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  AfterViewInit,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  Component,
  ElementRef,
  Injector,
  Input,
  ViewChild,
} from '@angular/core';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { TimezoneService } from 'core-app/core/datetime/timezone.service';
import { DayElement } from 'flatpickr/dist/types/instance';
import flatpickr from 'flatpickr';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { onDayCreate } from 'core-app/shared/components/datepicker/helpers/date-modal.helpers';
import { DeviceService } from 'core-app/core/browser/device.service';
import { DatePicker } from '../datepicker';
import { UntilDestroyedMixin } from 'core-app/shared/helpers/angular/until-destroyed.mixin';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { populateInputsFromDataset } from 'core-app/shared/components/dataset-inputs';
import { fromEvent } from 'rxjs';
import { filter } from 'rxjs/operators';
import * as _ from 'lodash';

@Component({
  selector: 'op-wp-modal-date-picker',
  template: `
    <input
      id="flatpickr-input"
      #flatpickrTarget
      hidden>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OpWpModalDatePickerComponent extends UntilDestroyedMixin implements AfterViewInit {
  @Input() public ignoreNonWorkingDays:boolean;
  @Input() public scheduleManually:boolean;

  @Input() public startDate:string|null;
  @Input() public dueDate:string|null;

  @Input() public isSchedulable:boolean = true;
  @Input() public minimalSchedulingDate:Date|null;

  @Input() startDateFieldId:string;
  @Input() dueDateFieldId:string;
  @Input() durationFieldId:string;

  @Input() isMilestone:boolean = false;

  @ViewChild('flatpickrTarget') flatpickrTarget:ElementRef;

  fieldName:'start_date'|'due_date'|'duration' = 'start_date';

  private datePickerInstance:DatePicker;
  private startDateValue:Date|null;
  private dueDateValue:Date|null;
  private onFlatpickrSetValuesBound = this.onFlatpickrSetValues.bind(this);

  constructor(
    readonly injector:Injector,
    readonly cdRef:ChangeDetectorRef,
    readonly apiV3Service:ApiV3Service,
    readonly I18n:I18nService,
    readonly timezoneService:TimezoneService,
    readonly deviceService:DeviceService,
    readonly pathHelper:PathHelperService,
    readonly elementRef:ElementRef,
  ) {
    super();
    populateInputsFromDataset(this);
    this.startDateValue = this.toDate(this.startDate);
    this.dueDateValue = this.toDate(this.dueDate);
  }

  ngAfterViewInit():void {
    this.initializeDatepicker();

    document.addEventListener('date-picker:flatpickr-set-values', this.onFlatpickrSetValuesBound);
  }

  // eslint-disable-next-line @angular-eslint/use-lifecycle-interface
  ngOnDestroy():void {
    super.ngOnDestroy();

    document.removeEventListener('date-picker:flatpickr-set-values', this.onFlatpickrSetValuesBound);
  }

  onFlatpickrSetValues(
    event:CustomEvent<{
      dates:Date[];
      ignoreNonWorkingDays:boolean;
      mode:'single'|'range';
    }>,
  ) {
    const details = event.detail;

    // try to set dates only if needed because if we set flatpickr dates,
    // flatpickr jumps the calendar date to the due date, which is annoying.
    if (this.isDifferentDates(details.dates, details.mode)) {
      [this.startDateValue, this.dueDateValue] = details.dates;
      this.datePickerInstance.setDates(details.dates);
    }
    this.datePickerInstance.setOption('mode', details.mode);

    if (this.ignoreNonWorkingDays !== details.ignoreNonWorkingDays) {
      this.ignoreNonWorkingDays = details.ignoreNonWorkingDays;
      this.datePickerInstance.datepickerInstance.redraw();
    }
  }

  private isDifferentDates(dates:Date[], mode:'single'|'range'):boolean {
    if (mode === 'single') {
      return dates[0].getTime() !== this.startDateValue?.getTime();
    }
    return dates[0].getTime() !== this.startDateValue?.getTime()
        || dates[1].getTime() !== this.dueDateValue?.getTime();
  }

  private toDate(date:string|null):Date|null {
    if (date) {
      return new Date(date);
    }
    return null;
  }

  private currentDates():Date[] {
    return _.compact([this.startDateValue, this.dueDateValue]);
  }

  private initializeDatepicker() {
    this.datePickerInstance?.destroy();
    this.fieldName = this.getActiveField();

    this.datePickerInstance = new DatePicker(
      this.injector,
      '#flatpickr-input',
      this.currentDates(),
      {
        mode: this.mode,
        showMonths: this.deviceService.isMobile ? 1 : 2,
        inline: true,
        onReady: (_date, _datestr, instance) => {
          instance.calendarContainer.classList.add('op-datepicker-modal--flatpickr-instance');

          this.ensureHoveredSelection(instance.calendarContainer);
        },
        onChange: this.onFlatpickrChange.bind(this),
        // eslint-disable-next-line @typescript-eslint/no-misused-promises
        onDayCreate: async (dObj:Date[], dStr:string, fp:flatpickr.Instance, dayElem:DayElement) => {
          onDayCreate(
            dayElem,
            this.ignoreNonWorkingDays,
            await this.datePickerInstance?.isNonWorkingDay(dayElem.dateObj),
            this.isDayDisabled(dayElem),
          );
        },
      },
      // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
      this.flatpickrTarget.nativeElement,
    );
  }

  private get mode():'single'|'range' {
    if (this.isMilestone) {
      return 'single';
    }

    // This is a very special case in which only one date is set, and we want to modify exactly that date again.
    // Then it does not make sense to display a range as we are only changing one date
    if (this.currentDates().length === 1) {
      if ((this.startDateValue !== null && this.fieldName === 'start_date') || (this.dueDateValue !== null && this.fieldName === 'due_date')) {
        return 'single';
      }
    }

    return 'range';
  }

  private onFlatpickrChange(dates:Date[], _datestr:string, _instance:flatpickr.Instance) {
    document.dispatchEvent(
      new CustomEvent('date-picker:flatpickr-dates-changed', {
        detail: { dates },
      }),
    );
  }

  private isDayDisabled(dayElement:DayElement):boolean {
    const minimalDate = this.minimalSchedulingDate || null;
    return !this.isSchedulable || (!this.scheduleManually && !!minimalDate && dayElement.dateObj <= minimalDate);
  }

  /**
   * When hovering selections in the range datepicker, the range usually
   * stays active no matter where the cursor is.
   *
   * We want to hide any hovered selection preview when we leave the datepicker.
   * @param calendarContainer
   * @private
   */
  private ensureHoveredSelection(calendarContainer:HTMLDivElement) {
    fromEvent(calendarContainer, 'mouseenter')
      .pipe(
        this.untilDestroyed(),
      )
      .subscribe(() => calendarContainer.classList.remove('flatpickr-container-suppress-hover'));

    fromEvent(calendarContainer, 'mouseleave')
      .pipe(
        this.untilDestroyed(),
        filter(() => !(!!this.startDateValue && !!this.dueDateValue)),
      )
      .subscribe(() => calendarContainer.classList.add('flatpickr-container-suppress-hover'));
  }

  private getActiveField():'start_date'|'due_date'|'duration' {
    const activeField = document.getElementsByClassName('op-datepicker-modal--date-field_current')[0];

    if (!activeField) {
      return this.fieldName;
    }

    switch (activeField.id) {
      case this.dueDateFieldId:
        return 'due_date';
      case this.durationFieldId:
        return 'duration';
      default:
        return 'start_date';
    }
  }
}

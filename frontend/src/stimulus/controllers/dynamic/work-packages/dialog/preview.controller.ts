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

import { Controller } from '@hotwired/stimulus';
import {
  debounce,
  DebouncedFunc,
} from 'lodash';
import Idiomorph from 'idiomorph/dist/idiomorph.cjs';

interface TurboBeforeFrameRenderEventDetail {
  render:(currentElement:HTMLElement, newElement:HTMLElement) => void;
}

interface HTMLTurboFrameElement extends HTMLElement {
  src:string;
}

export abstract class DialogPreviewController extends Controller {
  static targets = [
    'form',
    'fieldInput',
    'initialValueInput',
    'touchedFieldInput',
  ];

  declare readonly fieldInputTargets:HTMLInputElement[];
  declare readonly formTarget:HTMLFormElement;
  declare readonly initialValueInputTargets:HTMLInputElement[];
  declare readonly touchedFieldInputTargets:HTMLInputElement[];

  private debouncedDelayedPreview:DebouncedFunc<(input:HTMLInputElement) => void>;
  private debouncedImmediatePreview:DebouncedFunc<(input:HTMLInputElement) => void>;
  private frameMorphRenderer:(event:CustomEvent<TurboBeforeFrameRenderEventDetail>) => void;
  private targetFieldName:string;
  private touchedFields:Set<string>;

  connect() {
    this.touchedFields = new Set();
    this.touchedFieldInputTargets.forEach((input) => {
      const fieldName = input.dataset.referrerField;
      if (fieldName && input.value === 'true') {
        this.touchedFields.add(fieldName);
      }
    });

    // if the debounce value is changed, the following test helper must be kept
    // in sync: `spec/support/edit_fields/progress_edit_field.rb`, method `#wait_for_preview_to_complete`
    this.debouncedDelayedPreview = debounce((input:HTMLInputElement) => {
      void this.preview(input);
    }, 200);
    this.debouncedImmediatePreview = debounce((input:HTMLInputElement) => {
      void this.preview(input);
    }, 0);

    // Turbo supports morphing, by adding the <turbo-frame refresh="morph">
    // attribute. However, it does not work that well with primer input: when
    // adding "data-turbo-permanent" to keep value and focus on the active
    // element, it also keeps the `aria-describedby` attribute which references
    // caption and validation element ids. As these elements are morphed and get
    // new ids, the ids referenced by `aria-describedby` are stale. This makes
    // caption and validation message unaccessible for screen readers and other
    // assistive technologies. This is why morph cannot be used here.
    this.frameMorphRenderer = (event:CustomEvent<TurboBeforeFrameRenderEventDetail>) => {
      event.detail.render = (currentElement:HTMLElement, newElement:HTMLElement) => {
        Idiomorph.morph(currentElement, newElement, {
          ignoreActiveValue: true,
          callbacks: {
            beforeNodeMorphed: (oldNode:Element) => {
              // In case the element is an OpenProject custom dom element, morphing is prevented.
              return !oldNode.tagName?.startsWith('OPCE-');
            },
          },
        });
        this.afterRendering();
      };
    };

    this.fieldInputTargets.forEach((target) => {
      target.addEventListener('input', this.inputChanged.bind(this));

      if (target.dataset.focus === 'true') {
        this.focusAndSetCursorPositionToEndOfInput(target);
      }
    });

    const turboFrame = this.formTarget.closest('turbo-frame') as HTMLTurboFrameElement;
    turboFrame.addEventListener('turbo:before-frame-render', this.frameMorphRenderer);
  }

  disconnect() {
    this.debouncedDelayedPreview.cancel();
    this.debouncedImmediatePreview.cancel();
    this.fieldInputTargets.forEach((target) => {
      target.removeEventListener('input', this.inputChanged.bind(this));
    });
    const turboFrame = this.formTarget.closest('turbo-frame') as HTMLTurboFrameElement;
    if (turboFrame) {
      turboFrame.removeEventListener('turbo:before-frame-render', this.frameMorphRenderer);
    }
  }

  inputChanged(event:Event) {
    const field = event.target as HTMLInputElement;

    if (field.name === 'work_package[start_date]') {
      if (/^\d{4}-\d{2}-\d{2}$/.test(field.value)) {
        const selectedDate = new Date(field.value);
        this.changeStartDate(selectedDate);
        this.debouncedDelayedPreview(field);
      } else if (field.value === '') {
        this.debouncedDelayedPreview(field);
      }
    } else if (field.name === 'work_package[due_date]') {
      if (/^\d{4}-\d{2}-\d{2}$/.test(field.value)) {
        const selectedDate = new Date(field.value);
        this.changeDueDate(selectedDate);
        this.debouncedDelayedPreview(field);
      } else if (field.value === '') {
        this.debouncedDelayedPreview(field);
      }
    } else {
      this.debouncedDelayedPreview(field);
    }
  }

  changeStartDate(_selectedDate:Date) {
  }

  changeDueDate(_selectedDate:Date) {
  }

  protected triggerImmediatePreview(input:HTMLInputElement) {
    this.debouncedImmediatePreview(input);
  }

  protected cancel():void {
    document.dispatchEvent(new CustomEvent('cancelModalWithTurboContent'));
  }

  markFieldAsTouched(event:{ target:HTMLInputElement }) {
    const fieldName = event.target.name.replace(/^work_package\[([^\]]+)\]$/, '$1');
    this.doMarkFieldAsTouched(fieldName);
  }

  doMarkFieldAsTouched(fieldName:string) {
    this.targetFieldName = fieldName;
    this.markTouched(this.targetFieldName);
  }

  async preview(field:HTMLInputElement|null) {
    const form = this.formTarget;
    const formData = new FormData(form) as unknown as undefined;
    const formParams = new URLSearchParams(formData);

    const wpParams = Array.from(formParams.entries())
      .filter(([key, _]) => key.startsWith('work_package'));
    wpParams.push(['field', field?.name ?? '']);

    const wpPath = this.ensureValidPathname(form.action);
    const wpAction = this.ensureValidWpAction(wpPath);

    const editUrl = `${wpPath}/${wpAction}?${new URLSearchParams(wpParams).toString()}`;
    const turboFrame = this.formTarget.closest('turbo-frame') as HTMLTurboFrameElement;

    if (turboFrame) {
      turboFrame.src = editUrl;
    }
  }

  private focusAndSetCursorPositionToEndOfInput(field:HTMLInputElement) {
    field.focus();
    field.setSelectionRange(
      field.value.length,
      field.value.length,
    );
  }

  abstract ensureValidPathname(formAction:string):string;

  abstract ensureValidWpAction(path:string):string;

  abstract afterRendering():void;

  protected isBeingEdited(fieldName:string) {
    return fieldName === this.targetFieldName;
  }

  // Finds the hidden initial value input based on a field name.
  //
  // The initial value input field holds the initial value of the work package
  // before being set by the user or derived.
  private findInitialValueInput(fieldName:string):HTMLInputElement|undefined {
    return this.initialValueInputTargets.find((input) =>
      (input.dataset.referrerField === fieldName));
  }

  // Finds the value field input based on a field name.
  //
  // The value field input holds the current value of a field.
  protected findValueInput(fieldName:string):HTMLInputElement|undefined {
    return this.fieldInputTargets.find((input) =>
      (input.name === fieldName) || (input.name === `work_package[${fieldName}]`));
  }

  protected isTouchedAndEmpty(fieldName:string):boolean {
    return this.isTouched(fieldName) && this.isValueEmpty(fieldName);
  }

  protected isTouched(fieldName:string):boolean {
    return this.touchedFields.has(fieldName);
  }

  protected areBothTouched(fieldName1:string, fieldName2:string):boolean {
    return this.isTouched(fieldName1) && this.isTouched(fieldName2);
  }

  protected isInitialValueEmpty(fieldName:string):boolean {
    const valueInput = this.findInitialValueInput(fieldName);
    return valueInput?.value === '';
  }

  protected isValueEmpty(fieldName:string):boolean {
    const valueInput = this.findValueInput(fieldName);
    return valueInput?.value === '';
  }

  protected isValueSet(fieldName:string):boolean {
    const valueInput = this.findValueInput(fieldName);
    return valueInput !== undefined && valueInput.value !== '';
  }

  protected markTouched(fieldName:string):void {
    this.touchedFields.add(fieldName);
    this.updateTouchedFieldHiddenInputs();
  }

  protected markUntouched(fieldName:string):void {
    this.touchedFields.delete(fieldName);
    this.updateTouchedFieldHiddenInputs();
  }

  private updateTouchedFieldHiddenInputs():void {
    this.touchedFieldInputTargets.forEach((input) => {
      const fieldName = input.dataset.referrerField;
      if (fieldName) {
        input.value = this.isTouched(fieldName) ? 'true' : 'false';
      }
    });
  }

  protected keepFieldValueWithPriority(priority1:string, priority2:string, priority3:string) {
    if (this.isInitialValueEmpty(priority1) && !this.isTouched(priority1)) {
      // let priority field be derived
      return;
    }

    if (this.isBeingEdited(priority1)) {
      this.untouchFieldsWhenPriority1IsEdited(priority2, priority3);
    } else if (this.isBeingEdited(priority2)) {
      this.untouchFieldsWhenPriority2IsEdited(priority1, priority3);
    } else if (this.isBeingEdited(priority3)) {
      this.untouchFieldsWhenPriority3IsEdited(priority1, priority2);
    }
  }

  private untouchFieldsWhenPriority1IsEdited(priority2:string, priority3:string) {
    if (this.areBothTouched(priority2, priority3)) {
      if (this.isValueEmpty(priority3) && this.isValueEmpty(priority2)) {
        return;
      }
      if (this.isValueEmpty(priority3)) {
        this.markUntouched(priority3);
      } else {
        this.markUntouched(priority2);
      }
    } else if (this.isTouchedAndEmpty(priority2) && this.isValueSet(priority3)) {
      // force priority 2 derivation
      this.markUntouched(priority2);
      this.markTouched(priority3);
    } else if (this.isTouchedAndEmpty(priority3) && this.isValueSet(priority2)) {
      // force priority 3 derivation
      this.markUntouched(priority3);
      this.markTouched(priority2);
    }
  }

  private untouchFieldsWhenPriority2IsEdited(priority1:string, priority3:string):void {
    if (this.isTouchedAndEmpty(priority1) && this.isValueSet(priority3)) {
      // force priority 1 derivation
      this.markUntouched(priority1);
      this.markTouched(priority3);
    } else if (this.isValueSet(priority1)) {
      this.markUntouched(priority3);
    }
  }

  private untouchFieldsWhenPriority3IsEdited(priority1:string, priority2:string):void {
    if (this.isValueSet(priority1)) {
      this.markUntouched(priority2);
    }
  }
}

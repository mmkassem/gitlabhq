import { GlIcon, GlDeprecatedDropdownItem } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { createStore } from '~/logs/stores';
import { mockPods, mockPodName } from '../mock_data';

import LogSimpleFilters from '~/logs/components/log_simple_filters.vue';

const module = 'environmentLogs';

describe('LogSimpleFilters', () => {
  let store;
  let dispatch;
  let wrapper;
  let state;

  const findPodsDropdown = () => wrapper.find({ ref: 'podsDropdown' });
  const findPodsNoPodsText = () => wrapper.find({ ref: 'noPodsMsg' });
  const findPodsDropdownItems = () =>
    findPodsDropdown()
      .findAll(GlDeprecatedDropdownItem)
      .filter(item => !('disabled' in item.attributes()));

  const mockPodsLoading = () => {
    state.pods.options = [];
    state.pods.current = null;
  };

  const mockPodsLoaded = () => {
    state.pods.options = mockPods;
    state.pods.current = mockPodName;
  };

  const initWrapper = (propsData = {}) => {
    wrapper = shallowMount(LogSimpleFilters, {
      propsData: {
        ...propsData,
      },
      store,
    });
  };

  beforeEach(() => {
    store = createStore();
    state = store.state.environmentLogs;

    jest.spyOn(store, 'dispatch').mockResolvedValue();

    dispatch = store.dispatch;
  });

  afterEach(() => {
    store.dispatch.mockReset();

    if (wrapper) {
      wrapper.destroy();
    }
  });

  it('displays UI elements', () => {
    initWrapper();

    expect(wrapper.isVueInstance()).toBe(true);

    expect(findPodsDropdown().exists()).toBe(true);
  });

  describe('disabled state', () => {
    beforeEach(() => {
      mockPodsLoading();
      initWrapper({
        disabled: true,
      });
    });

    it('displays a disabled pods dropdown', () => {
      expect(findPodsDropdown().props('text')).toBe('No pod selected');
      expect(findPodsDropdown().attributes('disabled')).toBeTruthy();
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      mockPodsLoading();
      initWrapper();
    });

    it('displays an enabled pods dropdown', () => {
      expect(findPodsDropdown().attributes('disabled')).toBeFalsy();
      expect(findPodsDropdown().props('text')).toBe('No pod selected');
    });

    it('displays an empty pods dropdown', () => {
      expect(findPodsNoPodsText().exists()).toBe(true);
      expect(findPodsDropdownItems()).toHaveLength(0);
    });
  });

  describe('pods available state', () => {
    beforeEach(() => {
      mockPodsLoaded();
      initWrapper();
    });

    it('displays an enabled pods dropdown', () => {
      expect(findPodsDropdown().attributes('disabled')).toBeFalsy();
      expect(findPodsDropdown().props('text')).toBe(mockPods[0]);
    });

    it('displays a pods dropdown with items', () => {
      expect(findPodsNoPodsText().exists()).toBe(false);
      expect(findPodsDropdownItems()).toHaveLength(mockPods.length);
    });

    it('dropdown has one pod selected', () => {
      const items = findPodsDropdownItems();
      mockPods.forEach((pod, i) => {
        const item = items.at(i);
        if (item.text() !== mockPodName) {
          expect(item.find(GlIcon).classes('invisible')).toBe(true);
        } else {
          expect(item.find(GlIcon).classes('invisible')).toBe(false);
        }
      });
    });

    it('when the user clicks on a pod, showPodLogs is dispatched', () => {
      const items = findPodsDropdownItems();
      const index = 2; // any pod

      expect(dispatch).not.toHaveBeenCalledWith(`${module}/showPodLogs`, expect.anything());

      items.at(index).vm.$emit('click');

      expect(dispatch).toHaveBeenCalledWith(`${module}/showPodLogs`, mockPods[index]);
    });
  });
});

<script>
import { GlDeprecatedButton, GlIcon } from '@gitlab/ui';
import { escape } from 'lodash';
import { __, n__, sprintf, s__ } from '~/locale';

export default {
  components: {
    GlIcon,
    GlDeprecatedButton,
  },
  props: {
    isSquashEnabled: {
      type: Boolean,
      required: true,
    },
    isFastForwardEnabled: {
      type: Boolean,
      required: true,
    },
    commitsCount: {
      type: Number,
      required: false,
      default: 0,
    },
    targetBranch: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      expanded: false,
    };
  },
  computed: {
    collapseIcon() {
      return this.expanded ? 'chevron-down' : 'chevron-right';
    },
    commitsCountMessage() {
      return n__(__('%d commit'), __('%d commits'), this.isSquashEnabled ? 1 : this.commitsCount);
    },
    modifyLinkMessage() {
      if (this.isFastForwardEnabled) return __('Modify commit message');
      else if (this.isSquashEnabled) return __('Modify commit messages');
      return __('Modify merge commit');
    },
    ariaLabel() {
      return this.expanded ? __('Collapse') : __('Expand');
    },
    message() {
      const message = this.isFastForwardEnabled
        ? s__('mrWidgetCommitsAdded|%{commitCount} will be added to %{targetBranch}.')
        : s__(
            'mrWidgetCommitsAdded|%{commitCount} and %{mergeCommitCount} will be added to %{targetBranch}.',
          );

      return sprintf(
        message,
        {
          commitCount: `<strong class="commits-count-message">${this.commitsCountMessage}</strong>`,
          mergeCommitCount: `<strong>${s__('mrWidgetCommitsAdded|1 merge commit')}</strong>`,
          targetBranch: `<span class="label-branch">${escape(this.targetBranch)}</span>`,
        },
        false,
      );
    },
  },
  methods: {
    toggle() {
      this.expanded = !this.expanded;
    },
  },
};
</script>

<template>
  <div>
    <div
      class="js-mr-widget-commits-count mr-widget-extension clickable d-flex align-items-center px-3 py-2"
      @click="toggle()"
    >
      <gl-deprecated-button
        :aria-label="ariaLabel"
        variant="blank"
        class="commit-edit-toggle square s24 gl-mr-3"
        @click.stop="toggle()"
      >
        <gl-icon :name="collapseIcon" :size="16" />
      </gl-deprecated-button>
      <span v-if="expanded">{{ __('Collapse') }}</span>
      <span v-else>
        <span class="vertical-align-middle" v-html="message"></span>
        <gl-deprecated-button variant="link" class="modify-message-button">
          {{ modifyLinkMessage }}
        </gl-deprecated-button>
      </span>
    </div>
    <div v-show="expanded"><slot></slot></div>
  </div>
</template>

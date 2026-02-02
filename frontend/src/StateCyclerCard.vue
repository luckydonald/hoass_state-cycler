<script setup lang="ts">
import {
  computed,
  onMounted,
  onUnmounted,
  ref,
} from 'vue';
import type {
  CardConfig,
  HomeAssistant,
  StateCyclerEntity,
} from './types';

// Props
const props = defineProps<{
  hass: HomeAssistant | null;
  config: CardConfig;
}>();

// State
const currentTime = ref(new Date());
let timeInterval: ReturnType<typeof setInterval> | null = null;

// Lifecycle
onMounted(() => {
  timeInterval = setInterval(() => {
    currentTime.value = new Date();
  }, 1000);
});

onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval);
  }
});

// Computed
const cardTitle = computed(() => props.config.title || 'State Cycler');

const entity = computed((): StateCyclerEntity | null => {
  if (!props.hass || !props.config.entity) return null;
  const ent = props.hass.states[props.config.entity];
  if (!ent || !ent.entity_id.startsWith('state_cycler.')) return null;
  return ent as StateCyclerEntity;
});

const isOff = computed(() => entity.value?.attributes.toggle_state === false);

const currentStateFriendly = computed(() => entity.value?.attributes.state_friendly || 'Unknown');

const currentIndex = computed(() => entity.value?.attributes.index ?? -1);

const includeOffState = computed(() => entity.value?.attributes.include_off_state ?? false);

const states = computed(() => entity.value?.attributes.states || []);

// Helper to call service
async function callService(service: string, data: any = {}) {
  if (!props.hass || !props.config.entity) return;
  await props.hass.callService('state_cycler', service, {
    ...data,
    entity_id: props.config.entity,
  }, {
    entity_id: props.config.entity,
  });
}

// Actions
async function toggle() {
  await callService('switch');
}

async function next() {
  await callService('next');
}

async function cycle() {
  await callService('cycle');
}
</script>

<template>
  <ha-card>
    <div class="card-header">
      <div class="name">{{ cardTitle }}</div>
    </div>
    <div class="card-content">
      <div v-if="entity" class="state-info">
        <div class="current-state">
          <span class="label">Current:</span>
          <span class="value">{{ currentStateFriendly }}</span>
          <span class="index">(Index: {{ currentIndex }})</span>
        </div>
        <div class="toggle-state">
          <span class="label">Status:</span>
          <span class="value">{{ isOff ? 'Off' : 'On' }}</span>
        </div>
        <div class="include-off">
          <span class="label">Include Off:</span>
          <span class="value">{{ includeOffState ? 'Yes' : 'No' }}</span>
        </div>
      </div>
      <div v-else class="no-entity">
        <p>No State Cycler entity configured or found.</p>
      </div>

      <div v-if="entity" class="buttons">
        <ha-button @click="toggle" :disabled="!entity">
          {{ isOff ? 'Turn On' : 'Turn Off' }}
        </ha-button>
        <ha-button @click="next" :disabled="!entity">
          Next
        </ha-button>
        <ha-button @click="cycle" :disabled="!entity">
          Cycle
        </ha-button>
      </div>

      <div v-if="states.length > 0" class="states-list">
        <h4>States:</h4>
        <ul>
          <li v-for="(state, idx) in states" :key="state" :class="{ active: idx === currentIndex }">
            {{ state }}
          </li>
        </ul>
      </div>
    </div>
  </ha-card>
</template>

<style scoped lang="scss">
ha-card {
  padding: 16px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--divider-color);
}

.name {
  font-size: 24px;
  font-weight: 500;
  color: var(--primary-text-color);
}

.card-content {
  padding-top: 16px;
}

.state-info {
  margin-bottom: 16px;
}

.state-info > div {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
}

.label {
  font-weight: 500;
  color: var(--primary-text-color);
}

.value {
  color: var(--secondary-text-color);
}

.index {
  font-size: 0.9em;
  color: var(--disabled-text-color);
}

.buttons {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

.states-list h4 {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 500;
  color: var(--primary-text-color);
}

.states-list ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

.states-list li {
  padding: 4px 8px;
  margin-bottom: 4px;
  background: var(--secondary-background-color);
  border-radius: 4px;
  color: var(--primary-text-color);
}

.states-list li.active {
  background: var(--accent-color);
  color: var(--text-accent-color);
}

.warning {
  color: var(--error-color);
  font-style: italic;
}
</style>

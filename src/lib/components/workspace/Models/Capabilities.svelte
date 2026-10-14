<script lang="ts">
	import { getContext } from 'svelte';
	import type { Writable } from 'svelte/store';
	import type { i18n as i18nType } from 'i18next';
	import ModelSettingsSection from './ModelSettingsSection.svelte';
	import ModelSettingToggle from './ModelSettingToggle.svelte';
	import BuiltinTools from './BuiltinTools.svelte';

	const i18n: Writable<i18nType> = getContext('i18n');

	let capabilityLabels;
	$: capabilityLabels = {
		vision: {
			label: $i18n.t('settings.admin.models.capabilities.vision.label'),
			description: $i18n.t('settings.admin.models.capabilities.vision.description')
		},
		file_upload: {
			label: $i18n.t('settings.admin.models.capabilities.fileUpload.label'),
			description: $i18n.t('settings.admin.models.capabilities.fileUpload.description')
		},
		file_context: {
			label: $i18n.t('settings.admin.models.capabilities.fileContext.label'),
			description: $i18n.t('settings.admin.models.capabilities.fileContext.description')
		},
		web_search: {
			label: $i18n.t('settings.admin.models.capabilities.webSearch.label'),
			description: $i18n.t('settings.admin.models.capabilities.webSearch.description')
		},
		image_generation: {
			label: $i18n.t('settings.admin.models.capabilities.imageGeneration.label'),
			description: $i18n.t('settings.admin.models.capabilities.imageGeneration.description')
		},
		code_interpreter: {
			label: $i18n.t('settings.admin.models.capabilities.codeInterpreter.label'),
			description: $i18n.t('settings.admin.models.capabilities.codeInterpreter.description')
		},
		terminal: {
			label: $i18n.t('settings.admin.models.capabilities.terminal.label'),
			description: $i18n.t('settings.admin.models.capabilities.terminal.description')
		},
		usage: {
			label: $i18n.t('settings.admin.models.capabilities.usage.label'),
			description: $i18n.t('settings.admin.models.capabilities.usage.description')
		},
		citations: {
			label: $i18n.t('settings.admin.models.capabilities.citations.label'),
			description: $i18n.t('settings.admin.models.capabilities.citations.description')
		},
		status_updates: {
			label: $i18n.t('settings.admin.models.capabilities.statusUpdates.label'),
			description: $i18n.t('settings.admin.models.capabilities.statusUpdates.description')
		},
		memory: {
			label: $i18n.t('settings.admin.models.capabilities.memory.label'),
			description: $i18n.t('settings.admin.models.capabilities.memory.description')
		},
		builtin_tools: {
			label: $i18n.t('settings.admin.models.capabilities.builtinTools.label'),
			description: $i18n.t('settings.admin.models.capabilities.builtinTools.description')
		},
		raw_documents: {
			label: $i18n.t('Raw Documents'),
			description: $i18n.t('Model can send files directly to the API without RAG processing')
		}
	};

	type Capability = keyof typeof capabilityLabels;
	type DefaultFeature =
		| 'web_search'
		| 'native_web_search'
		| 'image_generation'
		| 'code_interpreter'
		| 'raw_documents';
	type DefaultFeatureDefinition = {
		capability: Capability;
		label: string;
		description: string;
	};

	const featureCapabilities: Record<DefaultFeature, Capability> = {
		web_search: 'web_search',
		native_web_search: 'web_search',
		image_generation: 'image_generation',
		code_interpreter: 'code_interpreter',
		raw_documents: 'raw_documents'
	};

	let defaultFeatureLabels: Record<DefaultFeature, DefaultFeatureDefinition>;
	$: defaultFeatureLabels = {
		web_search: {
			capability: 'web_search',
			label: $i18n.t('Web Search (External)'),
			description: $i18n.t('Enable RAG-based web search by default')
		},
		native_web_search: {
			capability: 'web_search',
			label: $i18n.t('Web Search (Native)'),
			description: $i18n.t('Enable provider-native web search by default')
		},
		image_generation: {
			capability: 'image_generation',
			label: capabilityLabels.image_generation.label,
			description: capabilityLabels.image_generation.description
		},
		code_interpreter: {
			capability: 'code_interpreter',
			label: capabilityLabels.code_interpreter.label,
			description: capabilityLabels.code_interpreter.description
		},
		raw_documents: {
			capability: 'raw_documents',
			label: $i18n.t('Raw Documents'),
			description: $i18n.t('Send files directly to the API without RAG processing by default')
		}
	};

	export let capabilities: Partial<Record<Capability, boolean>> = {};

	export let defaultFeatureIds: string[] = [];
	export let builtinTools: Record<string, boolean> = {};
	export let disabled = false;
	$: visibleCapabilities = (Object.keys(capabilityLabels) as Capability[]).filter(
		(key) => key !== 'file_context' || capabilities.file_upload
	);
	$: enabledCapabilityIds = visibleCapabilities.filter((key) => capabilities[key]);
	$: availableFeatures = (Object.keys(defaultFeatureLabels) as DefaultFeature[]).filter(
		(key) => capabilities[featureCapabilities[key]]
	);
	$: enabledDefaultIds = availableFeatures.filter((key) => defaultFeatureIds.includes(key));
	const setDefault = (key: string, enabled: boolean) => {
		defaultFeatureIds = enabled
			? [...new Set([...defaultFeatureIds, key])]
			: defaultFeatureIds.filter((id) => id !== key);
	};
</script>

<div class="space-y-0.5">
	<ModelSettingsSection
		label={$i18n.t('settings.admin.models.capabilities.title')}
		description={$i18n.t(
			'Choose which features are available for this model. The connected model and provider must support them.'
		)}
	>
		<span slot="summary" class="flex min-w-0 items-center gap-1 text-gray-900 dark:text-gray-100">
			<span class="min-w-0 truncate"
				>{enabledCapabilityIds
					.slice(0, 3)
					.map((key) => capabilityLabels[key].label)
					.join(', ') || $i18n.t('None')}</span
			>
			{#if enabledCapabilityIds.length > 3}<span class="shrink-0 text-gray-500"
					>+{enabledCapabilityIds.length - 3}</span
				>{/if}
		</span>
		<div class="grid grid-cols-1 gap-x-6 sm:grid-cols-2 lg:grid-cols-3">
			{#each visibleCapabilities as key}
				<ModelSettingToggle
					label={capabilityLabels[key].label}
					description={capabilityLabels[key].description}
					bind:checked={capabilities[key]}
					{disabled}
				/>
			{/each}
		</div>
	</ModelSettingsSection>

	<!-- Previous DefaultFeatures labels retained for i18n extraction:
	{$i18n.t('settings.admin.models.defaultFeatures.webSearch.label')}
	{$i18n.t('settings.admin.models.defaultFeatures.webSearch.description')}
	{$i18n.t('settings.admin.models.defaultFeatures.imageGeneration.label')}
	{$i18n.t('settings.admin.models.defaultFeatures.imageGeneration.description')}
	{$i18n.t('settings.admin.models.defaultFeatures.codeInterpreter.label')}
	{$i18n.t('settings.admin.models.defaultFeatures.codeInterpreter.description')}
	-->
	{#if availableFeatures.length}
		<ModelSettingsSection
			label={$i18n.t('settings.admin.models.defaultFeatures.title')}
			description={$i18n.t('Choose which available features start enabled in new chats.')}
		>
			<span slot="summary" class="flex min-w-0 items-center gap-1 text-gray-900 dark:text-gray-100">
				<span class="min-w-0 truncate"
					>{enabledDefaultIds
						.slice(0, 3)
						.map((key) => defaultFeatureLabels[key].label)
						.join(', ') || $i18n.t('None')}</span
				>
				{#if enabledDefaultIds.length > 3}<span class="shrink-0 text-gray-500"
						>+{enabledDefaultIds.length - 3}</span
					>{/if}
			</span>
			<p class="mb-1 px-1 text-xs text-gray-500 dark:text-gray-400">
				{$i18n.t('Start enabled in new chats')}
			</p>
			<div class="grid grid-cols-1 gap-x-6 sm:grid-cols-2 lg:grid-cols-3">
				{#each availableFeatures as key}
					<ModelSettingToggle
						label={defaultFeatureLabels[key].label}
						description={defaultFeatureLabels[key].description}
						checked={defaultFeatureIds.includes(key)}
						{disabled}
						on:change={(e) => setDefault(key, e.detail)}
					/>
				{/each}
			</div>
		</ModelSettingsSection>
	{/if}

	{#if capabilities.builtin_tools}
		<BuiltinTools bind:builtinTools {disabled} />
	{/if}
</div>

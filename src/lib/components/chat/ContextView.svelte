<script lang="ts">
	import { getContext } from 'svelte';
	import { settings } from '$lib/stores';
	import { createMessagesList } from '$lib/utils';
	import { previewChatContext } from '$lib/apis/openai';
	import Collapsible from '$lib/components/common/Collapsible.svelte';
	const i18n = getContext('i18n');

	export let history;
	export let prompt = '';
	export let files = [];
	export let chatParams = {};
	export let modelId = null;

	let rawJson = false;
	let showPreview = false;
	let previewContext = null;
	let previewLoading = false;
	let previewError = null;

	// Find the most recent enriched context from the message history.
	function findContext(history) {
		if (!history?.messages || !history?.currentId) return null;

		let cur = history.messages[history.currentId];
		for (let i = 0; i < 50 && cur; i++) {
			if (cur.enrichedContext) return cur.enrichedContext;
			cur = cur.parentId ? history.messages[cur.parentId] : null;
		}

		let latest = null;
		let latestTs = 0;
		for (const msg of Object.values(history.messages)) {
			if (msg.enrichedContext && (msg.timestamp ?? 0) >= latestTs) {
				latest = msg.enrichedContext;
				latestTs = msg.timestamp ?? 0;
			}
		}
		return latest;
	}

	$: capturedContext = findContext(history);

	async function refreshPreview() {
		previewLoading = true;
		previewError = null;
		try {
			// Build messages from history tree (same as real send)
			const rawMessages = history?.currentId
				? createMessagesList(history, history.currentId)
				: [];
			const messages = rawMessages
				.filter((m) => m.role !== 'system')
				.map((m) => ({
					role: m.role,
					content: m.content
				}));

			// Append pending user message
			if (prompt?.trim()) {
				messages.push({ role: 'user', content: prompt });
			}

			// Prepend system prompt
			const sysPrompt = chatParams?.system ?? $settings?.system ?? '';
			if (sysPrompt) {
				messages.unshift({ role: 'system', content: sysPrompt });
			}

			// Send the same payload shape as the real send flow
			const pendingFiles = (files ?? []).filter((f) => f.status === 'processed');
			const body = {
				model: modelId,
				messages,
				files: pendingFiles.length > 0 ? pendingFiles : undefined,
				params: {
					...($settings?.params ?? {}),
					...(chatParams ?? {})
				}
			};

			previewContext = await previewChatContext(localStorage.token, body);
			showPreview = true;
		} catch (err) {
			previewError = err?.detail ?? err?.message ?? String(err);
		} finally {
			previewLoading = false;
		}
	}

	$: context = showPreview ? previewContext : capturedContext;

	$: messages = context?.messages ?? [];
	$: tools = context?.tools ?? null;
	$: params = context?.params ?? {};
	$: paramKeys = Object.keys(params);

	function getRoleColor(role: string) {
		if (role === 'system') return 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300';
		if (role === 'user') return 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300';
		if (role === 'assistant') return 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300';
		return 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300';
	}

	function truncate(str: string, len = 300) {
		if (!str || str.length <= len) return str;
		return str.slice(0, len) + '...';
	}

	function getContentPreview(content: unknown): string {
		if (typeof content === 'string') return content;
		if (Array.isArray(content)) {
			const textParts = content
				.filter((p) => p.type === 'text')
				.map((p) => p.text);
			return textParts.join(' ');
		}
		return String(content ?? '');
	}
</script>

<div class="dark:text-gray-200 text-sm py-1 px-0.5">
	<!-- Toolbar -->
	<div class="flex items-center justify-between mb-2 px-1">
		<div class="flex items-center gap-1">
			{#if showPreview}
				<button
					class="text-xs px-2.5 py-1 rounded-lg transition font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 hover:bg-blue-200 dark:hover:bg-blue-900/50 disabled:opacity-50"
					on:click={refreshPreview}
					disabled={previewLoading}
				>
					{previewLoading ? $i18n.t('Loading...') : $i18n.t('Refresh Preview')}
				</button>
				<button
					class="text-xs px-2.5 py-1 rounded-lg transition text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800"
					on:click={() => (showPreview = false)}
				>
					{$i18n.t('Show Captured')}
				</button>
			{:else}
				<button
					class="text-xs px-2.5 py-1 rounded-lg transition font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 disabled:opacity-50"
					on:click={refreshPreview}
					disabled={previewLoading}
				>
					{previewLoading ? $i18n.t('Loading...') : $i18n.t('Preview Context')}
				</button>
			{/if}
		</div>
		<button
			class="text-xs px-2 py-1 rounded transition {rawJson
				? 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
				: 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}"
			on:click={() => (rawJson = !rawJson)}
		>
			{rawJson ? $i18n.t('Formatted') : $i18n.t('Raw JSON')}
		</button>
	</div>

	{#if previewError}
		<div class="text-xs text-red-500 dark:text-red-400 px-1 mb-2">
			{previewError}
		</div>
	{/if}

	{#if !context}
		<div class="text-center text-gray-500 dark:text-gray-400 py-8 px-2">
			<div class="text-sm">{$i18n.t('No context data available')}</div>
			<div class="text-xs mt-1 text-gray-400 dark:text-gray-500">
				{$i18n.t('Context is captured when a new message is generated')}
			</div>
		</div>
	{:else}
		{#if rawJson}
			<pre class="text-xs bg-gray-50 dark:bg-gray-900 rounded-lg p-3 overflow-x-auto whitespace-pre-wrap break-words max-h-[70vh] overflow-y-auto">{JSON.stringify(context, null, 2)}</pre>
		{:else}
			<!-- Messages Section -->
			<Collapsible title={$i18n.t('Messages')} open={true}>
				<div slot="content" class="flex flex-col gap-2 mt-1.5">
					{#each messages as msg, idx}
						<div class="border border-gray-100 dark:border-gray-800 rounded-lg overflow-hidden">
							<div class="flex items-center gap-2 px-3 py-1.5 bg-gray-50 dark:bg-gray-850">
								<span class="text-xs font-medium px-1.5 py-0.5 rounded {getRoleColor(msg.role)}">
									{msg.role}
								</span>
								<span class="text-xs text-gray-400 dark:text-gray-500 truncate flex-1">
									{#if typeof msg.content === 'string'}
										{truncate(msg.content, 80)}
									{:else if Array.isArray(msg.content)}
										{truncate(getContentPreview(msg.content), 80)}
									{:else}
										[{typeof msg.content}]
									{/if}
								</span>
							</div>
							<div class="px-3 py-2 text-xs">
								{#if typeof msg.content === 'string'}
									<pre class="whitespace-pre-wrap break-words text-gray-700 dark:text-gray-300 max-h-60 overflow-y-auto">{msg.content}</pre>
								{:else if Array.isArray(msg.content)}
									{#each msg.content as part, partIdx}
										{#if part.type === 'text'}
											<pre class="whitespace-pre-wrap break-words text-gray-700 dark:text-gray-300 max-h-60 overflow-y-auto mb-1">{part.text}</pre>
										{:else if part.type === 'image_url'}
											<div class="text-gray-500 dark:text-gray-400 italic py-1">
												{part.image_url?.url ?? '[image]'}
											</div>
										{:else}
											<div class="text-gray-500 dark:text-gray-400 italic py-1">
												[{part.type}]
											</div>
										{/if}
									{/each}
								{:else}
									<pre class="whitespace-pre-wrap break-words text-gray-700 dark:text-gray-300">{JSON.stringify(msg.content, null, 2)}</pre>
								{/if}
							</div>
						</div>
					{/each}
				</div>
			</Collapsible>

			<!-- Tools Section -->
			{#if tools && tools.length > 0}
				<div class="mt-2">
					<Collapsible title="{$i18n.t('Tools')} ({tools.length})" open={false}>
						<div slot="content" class="flex flex-col gap-1.5 mt-1.5">
							{#each tools as tool, idx}
								<div class="border border-gray-100 dark:border-gray-800 rounded-lg overflow-hidden">
									<div class="px-3 py-1.5 bg-gray-50 dark:bg-gray-850 text-xs font-medium text-gray-700 dark:text-gray-300">
										{tool?.function?.name ?? tool?.name ?? 'unknown'}
									</div>
									<div class="px-3 py-2 text-xs text-gray-500 dark:text-gray-400">
										{tool?.function?.description ?? ''}
									</div>
								</div>
							{/each}
						</div>
					</Collapsible>
				</div>
			{/if}

			<!-- Model Parameters Section -->
			{#if paramKeys.length > 0}
				<div class="mt-2">
					<Collapsible title={$i18n.t('Model Parameters')} open={false}>
						<div slot="content" class="mt-1.5">
							<div class="border border-gray-100 dark:border-gray-800 rounded-lg overflow-hidden">
								<table class="w-full text-xs">
									<tbody>
										{#each paramKeys as key}
											<tr class="border-b border-gray-50 dark:border-gray-800 last:border-0">
												<td class="px-3 py-1.5 font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap">{key}</td>
												<td class="px-3 py-1.5 text-gray-700 dark:text-gray-300 break-all">
													{#if typeof params[key] === 'object'}
														<pre class="whitespace-pre-wrap">{JSON.stringify(params[key])}</pre>
													{:else}
														{String(params[key])}
													{/if}
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						</div>
					</Collapsible>
				</div>
			{/if}
		{/if}
	{/if}
</div>

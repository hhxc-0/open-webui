<script lang="ts">
	import dayjs from 'dayjs';
	import { onMount, tick, getContext } from 'svelte';

	import { decodeString } from '$lib/utils';
	import { getChatList } from '$lib/apis/chats';

	import Tooltip from '$lib/components/common/Tooltip.svelte';
	import Spinner from '$lib/components/common/Spinner.svelte';
	import Loader from '$lib/components/common/Loader.svelte';
	import FolderTree from './FolderTree.svelte';
	import { chatId } from '$lib/stores';

	const i18n = getContext('i18n');

	export let onSelect = (e) => {};

	let viewMode: 'list' | 'folders' = 'list';
	let loaded = false;

	let items = [];
	let selectedIdx = 0;

	let page = 1;
	let itemsLoading = false;
	let allItemsLoaded = false;

	const loadMoreItems = async () => {
		if (allItemsLoaded) return;
		page += 1;
		await getItemsPage();
	};

	const getItemsPage = async () => {
		itemsLoading = true;
		let res = await getChatList(localStorage.token, page, true, true).catch(() => {
			return [];
		});

		if ((res ?? []).length === 0) {
			allItemsLoaded = true;
		} else {
			allItemsLoaded = false;
		}

		items = [
			...items,
			...res
				.filter((item) => item?.id !== $chatId)
				.map((item) => {
					return {
						...item,
						type: 'chat',
						name: item.title,
						description: dayjs(item.updated_at * 1000).fromNow()
					};
				})
		];

		itemsLoading = false;
		return res;
	};

	onMount(async () => {
		await getItemsPage();
		await tick();

		loaded = true;
	});
</script>

{#if loaded}
	<!-- Segmented control toggle -->
	<div class="flex items-center gap-1 px-1 py-1 mb-1">
		<button
			class="flex-1 px-2 py-1 text-xs rounded-lg transition {viewMode === 'list'
				? 'bg-gray-100 dark:bg-gray-800 font-medium text-gray-900 dark:text-white'
				: 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}"
			on:click={() => (viewMode = 'list')}
		>
			{$i18n.t('List')}
		</button>
		<button
			class="flex-1 px-2 py-1 text-xs rounded-lg transition {viewMode === 'folders'
				? 'bg-gray-100 dark:bg-gray-800 font-medium text-gray-900 dark:text-white'
				: 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'}"
			on:click={() => (viewMode = 'folders')}
		>
			{$i18n.t('Folders')}
		</button>
	</div>

	{#if viewMode === 'list'}
		{#if items.length === 0}
			<div class="text-center text-xs text-gray-500 py-3">{$i18n.t('No chats found')}</div>
		{:else}
			<div class="flex flex-col gap-0.5">
				{#each items as item, idx}
					<button
						class=" px-2.5 py-1 rounded-xl w-full text-left flex justify-between items-center text-sm {idx ===
						selectedIdx
							? ' bg-gray-50 dark:bg-gray-800 dark:text-gray-100 selected-command-option-button'
							: ''}"
						type="button"
						on:click={() => {
							onSelect(item);
						}}
						on:mousemove={() => {
							selectedIdx = idx;
						}}
						on:mouseleave={() => {
							if (idx === 0) {
								selectedIdx = -1;
							}
						}}
						data-selected={idx === selectedIdx}
					>
						<div class="text-black dark:text-gray-100 flex items-center gap-1.5">
							<Tooltip content={item.description || decodeString(item?.name)} placement="top-start">
								<div class="line-clamp-1 flex-1">
									{decodeString(item?.name)}
								</div>
							</Tooltip>
						</div>
					</button>
				{/each}

				{#if !allItemsLoaded}
					<Loader
						on:visible={(e) => {
							if (!itemsLoading) {
								loadMoreItems();
							}
						}}
					>
						<div class="w-full flex justify-center py-4 text-xs animate-pulse items-center gap-2">
							<Spinner className=" size-4" />
							<div class=" ">{$i18n.t('Loading...')}</div>
						</div>
					</Loader>
				{/if}
			</div>
		{/if}
	{:else}
		<FolderTree {onSelect} />
	{/if}
{:else}
	<div class="py-4.5">
		<Spinner />
	</div>
{/if}

<script lang="ts">
	import { onMount, tick, getContext } from 'svelte';
	import { toast } from 'svelte-sonner';

	import { getFolders } from '$lib/apis/folders';
	import { getChatListByFolderId, getChatsByFolderId } from '$lib/apis/chats';
	import { chatId } from '$lib/stores';

	import ChevronDown from '$lib/components/icons/ChevronDown.svelte';
	import ChevronRight from '$lib/components/icons/ChevronRight.svelte';
	import FolderOpen from '$lib/components/icons/FolderOpen.svelte';
	import Spinner from '$lib/components/common/Spinner.svelte';

	const i18n = getContext('i18n');

	export let onSelect = (item, batch = false) => {};

	let loaded = false;
	let folders = {}; // { [id]: { id, name, parent_id, childrenIds: [] } }
	let topFolderIds = []; // folder ids with no parent

	// Track expanded state and loaded chats per folder
	let expanded = {}; // { [folderId]: boolean }
	let folderChats = {}; // { [folderId]: chat[] }
	let loadingFolders = {}; // { [folderId]: boolean }

	onMount(async () => {
		try {
			const res = await getFolders(localStorage.token);
			if (res) {
				const map = {};
				for (const f of res) {
					map[f.id] = { ...f, childrenIds: [] };
				}
				// Build parent → children relationships
				for (const f of res) {
					if (f.parent_id && map[f.parent_id]) {
						map[f.parent_id].childrenIds.push(f.id);
					}
				}
				folders = map;
				topFolderIds = res
					.filter((f) => !f.parent_id)
					.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' }))
					.map((f) => f.id);
			}
		} catch (e) {
			console.error('Failed to load folders:', e);
		}
		loaded = true;
	});

	const toggleFolder = async (folderId: string) => {
		if (expanded[folderId]) {
			expanded[folderId] = false;
			expanded = expanded;
			return;
		}

		expanded[folderId] = true;
		expanded = expanded;

		if (!folderChats[folderId]) {
			loadingFolders[folderId] = true;
			loadingFolders = loadingFolders;

			try {
				const chats = await getChatListByFolderId(localStorage.token, folderId);
				folderChats[folderId] = (chats ?? []).filter((c) => c.id !== $chatId);
			} catch (e) {
				console.error('Failed to load folder chats:', e);
				folderChats[folderId] = [];
			}

			folderChats = folderChats;
			loadingFolders[folderId] = false;
			loadingFolders = loadingFolders;
		}
	};

	const addAllChatsInFolder = async (folderId: string) => {
		try {
			const chats = await getChatsByFolderId(localStorage.token, folderId);
			if (chats) {
				const filtered = chats.filter((c) => c.id !== $chatId);
				for (const chat of filtered) {
					onSelect(
						{
							type: 'chat',
							id: chat.id,
							name: chat.title || chat.name || 'Untitled',
							collection_name: '',
							status: 'processed'
						},
						true
					);
				}
				toast.success(
					$i18n.t('Added {{count}} chats from folder', { count: filtered.length })
				);
			}
		} catch (e) {
			console.error('Failed to add folder chats:', e);
			toast.error($i18n.t('Failed to load folder chats'));
		}
	};

	const addChat = (chat: any) => {
		onSelect({
			type: 'chat',
			id: chat.id,
			name: chat.title || chat.name || 'Untitled',
			collection_name: '',
			status: 'processed'
		});
	};

	const sortedChildren = (folderId: string) => {
		return (folders[folderId]?.childrenIds ?? [])
			.map((id) => folders[id])
			.filter(Boolean)
			.sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' }));
	};
</script>

{#if loaded}
	{#if topFolderIds.length === 0}
		<div class="text-center text-xs text-gray-500 py-3">{$i18n.t('No folders found')}</div>
	{:else}
		<div class="flex flex-col gap-0.5">
			{#each topFolderIds as folderId (folderId)}
				{@render folderRow(folderId, 0)}
			{/each}
		</div>
	{/if}
{:else}
	<div class="py-4.5 flex justify-center">
		<Spinner />
	</div>
{/if}

{#snippet folderRow(folderId, depth)}
	{@const folder = folders[folderId]}
	{#if folder}
		<div>
			<!-- Folder header -->
			<div class="flex items-center group">
				<button
					class="p-1 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300 transition shrink-0"
					style="margin-left: {depth * 12}px"
					on:click={() => toggleFolder(folderId)}
				>
					{#if expanded[folderId]}
						<ChevronDown className="size-3" />
					{:else}
						<ChevronRight className="size-3" />
					{/if}
				</button>

				<button
					class="flex-1 px-1.5 py-1 rounded-lg text-left flex items-center gap-1.5 text-sm hover:bg-gray-50 dark:hover:bg-gray-800/50 transition min-w-0"
					on:click={() => toggleFolder(folderId)}
				>
					<FolderOpen className="size-3.5 shrink-0 text-gray-400 dark:text-gray-500" />
					<span class="line-clamp-1 flex-1">{folder.name}</span>
				</button>

				<button
					class="p-1 text-gray-400 dark:text-gray-500 hover:text-blue-500 dark:hover:text-blue-400 transition opacity-0 group-hover:opacity-100 shrink-0"
					title={$i18n.t('Add all chats in folder')}
					on:click|stopPropagation={() => addAllChatsInFolder(folderId)}
				>
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="size-3.5">
						<path d="M8 2a.75.75 0 0 1 .75.75v4.5h4.5a.75.75 0 0 1 0 1.5h-4.5v4.5a.75.75 0 0 1-1.5 0v-4.5h-4.5a.75.75 0 0 1 0-1.5h4.5v-4.5A.75.75 0 0 1 8 2Z" />
					</svg>
				</button>
			</div>

			<!-- Expanded content -->
			{#if expanded[folderId]}
				<div class="ml-3 pl-1 flex flex-col border-l border-gray-100 dark:border-gray-800">
					<!-- Child folders -->
					{#each sortedChildren(folderId) as child (child.id)}
						{@render folderRow(child.id, depth + 1)}
					{/each}

					<!-- Chats in this folder -->
					{#if loadingFolders[folderId]}
						<div class="flex justify-center items-center p-2">
							<Spinner className="size-4 text-gray-500" />
						</div>
					{:else}
						{#each (folderChats[folderId] ?? []) as chat (chat.id)}
							<button
								class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-left text-sm hover:bg-gray-50 dark:hover:bg-gray-800/50 transition"
								style="margin-left: {(depth + 1) * 12}px"
								on:click={() => addChat(chat)}
							>
								<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="size-3.5 text-gray-400 dark:text-gray-500 shrink-0">
									<path fill-rule="evenodd" d="M8 2C4.691 2 2 4.477 2 7.538c0 1.587.835 2.98 2.086 3.885-.047 1.196-.596 2.293-.838 2.724a.445.445 0 0 0 .166.567c.163.108.382.058.52-.053C5.686 13.95 6.67 13.562 7.5 13.3c.396.078.82.138 1.25.138 3.309 0 6-2.477 6-5.538C14.75 4.477 12.091 2 8.75 2H8Z" clip-rule="evenodd" />
								</svg>
								<span class="line-clamp-1 flex-1">{chat.title || chat.name || 'Untitled'}</span>
							</button>
						{/each}

						{#if (folderChats[folderId] ?? []).length === 0}
							<div class="text-xs text-gray-400 dark:text-gray-500 py-1 px-2" style="margin-left: {(depth + 1) * 12}px">
								{$i18n.t('No chats found')}
							</div>
						{/if}
					{/if}
				</div>
			{/if}
		</div>
	{/if}
{/snippet}

<script lang="ts">
	import { getContext } from 'svelte';
	import { toast } from 'svelte-sonner';

	import { generateTranslation } from '$lib/apis';
	import { copyToClipboard } from '$lib/utils';
	import Tooltip from '$lib/components/common/Tooltip.svelte';
	import Clipboard from '$lib/components/icons/Clipboard.svelte';
	import Markdown from './Markdown.svelte';

	const i18n = getContext('i18n');

	export let content = '';
	export let model = '';
	export let messageId = '';

	let translatedContent = '';
	let translatedSource = '';
	let targetLanguage: 'English' | 'Chinese' = 'Chinese';
	export let loading = false;

	const containsChinese = (text: string) => /[\u3400-\u9fff\uf900-\ufaff]/.test(text);

	export const translate = async () => {
		if (!content.trim() || !model || loading) return;

		targetLanguage = containsChinese(content) ? 'English' : 'Chinese';
		loading = true;

		try {
			translatedContent = await generateTranslation(
				localStorage.token,
				model,
				content,
				targetLanguage
			);
			translatedSource = content;
		} catch (error) {
			console.error(error);
			toast.error($i18n.t('Failed to translate message.'));
		} finally {
			loading = false;
		}
	};

	const copyTranslation = async () => {
		if (await copyToClipboard(translatedContent)) {
			toast.success($i18n.t('Copying to clipboard was successful!'));
		}
	};

	$: if (translatedSource && translatedSource !== content) {
		translatedContent = '';
		translatedSource = '';
	}
</script>

{#if translatedContent}
	<div class="mt-2 border-t border-gray-100 pt-2 text-sm dark:border-gray-800">
		<div
			class="mb-1 flex items-center justify-between gap-2 text-xs text-gray-500 dark:text-gray-400"
		>
			<span>{targetLanguage === 'Chinese' ? 'EN → ZH' : 'ZH → EN'}</span>
			<Tooltip content={$i18n.t('Copy')} placement="bottom">
				<button
					type="button"
					aria-label={$i18n.t('Copy translation')}
					class="rounded p-1 hover:bg-black/5 dark:hover:bg-white/5"
					on:click={copyTranslation}
				>
					<Clipboard className="w-4 h-4" strokeWidth="2" />
				</button>
			</Tooltip>
		</div>
		<div class="markdown-prose text-gray-700 dark:text-gray-300">
			<Markdown id={`${messageId}-translation`} content={translatedContent} />
		</div>
	</div>
{/if}

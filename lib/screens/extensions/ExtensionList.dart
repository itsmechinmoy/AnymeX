import 'package:anymex/core/Extensions/fetch_novel_sources.dart';
import 'package:anymex/models/Media/media.dart';
import 'package:anymex/utils/extensions.dart';
import 'package:anymex/utils/language.dart';
import 'package:anymex/widgets/custom_widgets/anymex_button.dart';
import 'package:anymex/widgets/custom_widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:anymex/widgets/custom_widgets/anymex_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grouped_list/sliver_grouped_list.dart';

import '../../core/Extensions/get_sources_list.dart';
import '../../core/Extensions/extensions_provider.dart';
import '../../core/Extensions/fetch_anime_sources.dart';
import '../../core/Extensions/fetch_manga_sources.dart';
import '../../core/Model/Source.dart';
import 'ExtensionItem.dart';

class Extension extends ConsumerStatefulWidget {
  final bool installed;
  final MediaType mediaType;
  final String query;
  final String selectedLanguage;
  final bool showRecommended;

  const Extension({
    required this.installed,
    required this.query,
    required this.mediaType,
    required this.selectedLanguage,
    this.showRecommended = true,
    super.key,
  });

  @override
  ConsumerState<Extension> createState() => _ExtensionScreenState();
}

class _ExtensionScreenState extends ConsumerState<Extension> {
  final controller = ScrollController();

  Future<void> _refreshData() async {
    if (widget.mediaType == MediaType.manga) {
      return await ref.refresh(
          fetchMangaSourcesListProvider(id: null, reFresh: true).future);
    } else if (widget.mediaType == MediaType.anime) {
      return await ref.refresh(
          fetchAnimeSourcesListProvider(id: null, reFresh: true).future);
    } else {
      return await ref.refresh(
          fetchNovelSourcesListProvider(id: null, reFresh: true).future);
    }
  }

  Future<void> _fetchData() async {
    if (widget.mediaType == MediaType.manga) {
      ref.watch(fetchMangaSourcesListProvider(id: null, reFresh: false));
    } else if (widget.mediaType == MediaType.anime) {
      ref.watch(fetchAnimeSourcesListProvider(id: null, reFresh: false));
    } else {
      ref.watch(fetchNovelSourcesListProvider(id: null, reFresh: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamExtensions =
        ref.watch(getExtensionsStreamProvider(widget.mediaType));

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: streamExtensions.when(
          data: (data) {
            data = _filterData(data);
            final installedEntries = _getInstalledEntries(data);
            final updateEntries = _getUpdateEntries(data);
            final notInstalledEntries = _getNotInstalledEntries(data);
            final recommendedEntries = widget.showRecommended
                ? _getRecommendedEntries(data)
                : [].cast<Source>();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  if (widget.showRecommended && (recommendedEntries.isNotEmpty))
                    _buildRecommendedList(recommendedEntries),
                  if (widget.installed) _buildUpdatePendingList(updateEntries),
                  if (widget.installed) _buildInstalledList(installedEntries),
                  if (!widget.installed)
                    _buildNotInstalledList(notInstalledEntries),
                ],
              ),
            );
          },
          error: (error, _) => Center(
            child: AnymexButton(
              onTap: () => _fetchData(),
              child: const Text('Refresh'),
            ),
          ),
          loading: () => const Center(child: AnymexProgressIndicator()),
        ),
      ),
    );
  }

  List<Source> _filterData(List<Source> data) {
    return data
        .where((element) => widget.selectedLanguage != 'all'
            ? element.lang!.toLowerCase() ==
                completeLanguageCode(widget.selectedLanguage)
            : true)
        .where((element) =>
            widget.query.isEmpty ||
            element.name!.toLowerCase().contains(widget.query.toLowerCase()))
        .toList();
  }

  List<Source> _getInstalledEntries(List<Source> data) {
    return data
        .where((element) => element.version == element.versionLast!)
        .where((element) => element.isAdded!)
        .toList();
  }

  List<Source> _getUpdateEntries(List<Source> data) {
    return data
        .where((element) =>
            compareVersions(element.version!, element.versionLast!) < 0)
        .where((element) => element.isAdded!)
        .toList();
  }

  List<Source> _getNotInstalledEntries(List<Source> data) {
    return data
        .where((element) => element.version == element.versionLast!)
        .where((element) => !element.isAdded!)
        .toList();
  }

  List<Source> _getRecommendedEntries(List<Source> data) {
    final extens = [
      'anymex',
    ];

    return data.where((element) {
      final name = element.name?.toLowerCase() ?? '';
      final lang = element.lang?.toLowerCase() ?? '';
      final matchesExtension = extens.any((ext) => name.contains(ext));
      return matchesExtension &&
          (lang == 'en' || lang == 'all' || lang == 'multi');
    }).toList();
  }

  SliverGroupedListView<Source, String> _buildUpdatePendingList(
      List<Source> updateEntries) {
    return SliverGroupedListView<Source, String>(
      elements: updateEntries,
      groupBy: (element) => "",
      groupSeparatorBuilder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Update Pending',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            AnymeXButton(
              variant: ButtonVariant.outline,
              onTap: () async {
                for (var source in updateEntries) {
                  widget.mediaType == MediaType.manga
                      ? await ref.watch(fetchMangaSourcesListProvider(
                              id: source.id, reFresh: true)
                          .future)
                      : await ref.watch(fetchAnimeSourcesListProvider(
                              id: source.id, reFresh: true)
                          .future);
                }
              },
              child: const Text(
                'Update All',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context, Source element) => ExtensionListTileWidget(
        source: element,
        mediaType: widget.mediaType,
      ),
      groupComparator: (group1, group2) => group1.compareTo(group2),
      itemComparator: (item1, item2) => item1.name!.compareTo(item2.name!),
      order: GroupedListOrder.ASC,
    );
  }

  SliverGroupedListView<Source, String> _buildInstalledList(
      List<Source> installedEntries) {
    return SliverGroupedListView<Source, String>(
      elements: installedEntries,
      groupBy: (element) => "",
      groupSeparatorBuilder: (_) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(),
      ),
      itemBuilder: (context, Source element) => ExtensionListTileWidget(
        source: element,
        mediaType: widget.mediaType,
      ),
      groupComparator: (group1, group2) => group1.compareTo(group2),
      itemComparator: (item1, item2) => item1.name!.compareTo(item2.name!),
      order: GroupedListOrder.ASC,
    );
  }

  // New method to build recommended list
  SliverGroupedListView<Source, String> _buildRecommendedList(
      List<Source> recommendedEntries) {
    return SliverGroupedListView<Source, String>(
      elements: recommendedEntries,
      groupBy: (element) => "",
      groupSeparatorBuilder: (_) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(
              'Recommended',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      itemBuilder: (context, Source element) => ExtensionListTileWidget(
        source: element,
        mediaType: widget.mediaType,
      ),
      groupComparator: (group1, group2) => group1.compareTo(group2),
      itemComparator: (item1, item2) => item1.name!.compareTo(item2.name!),
      order: GroupedListOrder.ASC,
    );
  }

  SliverGroupedListView<Source, String> _buildNotInstalledList(
      List<Source> notInstalledEntries) {
    return SliverGroupedListView<Source, String>(
      elements: notInstalledEntries,
      groupBy: (element) => completeLanguageName(element.lang!.toLowerCase()),
      groupSeparatorBuilder: (String groupByValue) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Text(
              groupByValue,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      itemBuilder: (context, Source element) => ExtensionListTileWidget(
        source: element,
        mediaType: widget.mediaType,
      ),
      groupComparator: (group1, group2) => group1.compareTo(group2),
      itemComparator: (item1, item2) => item1.name!.compareTo(item2.name!),
      order: GroupedListOrder.ASC,
    );
  }
}

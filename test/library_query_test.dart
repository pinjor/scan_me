import 'package:flutter_test/flutter_test.dart';
import 'package:scanme/core/providers.dart';
import 'package:scanme/core/services/convert_outputs_service.dart';
import 'package:scanme/shared/models/library_models.dart';
import 'package:scanme/shared/models/scanned_document.dart';

ScannedDocument _doc({
  required String id,
  required String name,
  bool favorite = false,
  String? folderId,
  List<String> tags = const [],
  bool trash = false,
  int pages = 1,
  int? size,
  DateTime? created,
  DateTime? updated,
}) {
  final now = DateTime(2026, 8, 13);
  return ScannedDocument(
    id: id,
    name: name,
    createdAt: created ?? now,
    updatedAt: updated ?? now,
    isFavorite: favorite,
    folderId: folderId,
    tags: tags,
    deletedAt: trash ? now : null,
    fileSizeBytes: size,
    pages: [
      for (var i = 0; i < pages; i++)
        ScannedPage(
          id: '$id-p$i',
          originalImagePath: '/tmp/$id-$i.jpg',
          pageIndex: i,
        ),
    ],
  );
}

void main() {
  final docs = [
    _doc(
      id: 'a',
      name: 'Alpha invoice',
      favorite: true,
      folderId: 'work',
      tags: ['finance', 'urgent'],
      pages: 3,
      size: 5000,
      updated: DateTime(2026, 8, 12),
      created: DateTime(2026, 8, 1),
    ),
    _doc(
      id: 'b',
      name: 'Beta notes',
      tags: ['personal'],
      pages: 1,
      size: 1000,
      updated: DateTime(2026, 8, 13),
      created: DateTime(2026, 8, 10),
    ),
    _doc(
      id: 'c',
      name: 'Charlie receipt',
      folderId: 'receipts',
      tags: ['finance'],
      pages: 2,
      size: 3000,
      updated: DateTime(2026, 8, 11),
      created: DateTime(2026, 8, 5),
    ),
    _doc(
      id: 'd',
      name: 'Deleted draft',
      trash: true,
      updated: DateTime(2026, 8, 9),
    ),
  ];

  test('library excludes trash by default', () {
    final list = filterAndSortDocuments(docs, const LibraryQuery());
    expect(list.map((d) => d.id), ['a', 'b', 'c']);
  });

  test('trash mode shows only deleted', () {
    final list = filterAndSortDocuments(
      docs,
      const LibraryQuery(showTrash: true),
    );
    expect(list.map((d) => d.id), ['d']);
  });

  test('favoritesOnly filter', () {
    final list = filterAndSortDocuments(
      docs,
      const LibraryQuery(favoritesOnly: true),
    );
    expect(list.map((d) => d.id), ['a']);
  });

  test('folder and unfiled filters', () {
    final byFolder = filterAndSortDocuments(
      docs,
      const LibraryQuery(folderId: 'work'),
    );
    expect(byFolder.map((d) => d.id), ['a']);

    final unfiled = filterAndSortDocuments(
      docs,
      const LibraryQuery(unfiledOnly: true),
    );
    expect(unfiled.map((d) => d.id), ['b']);
  });

  test('tag and search filters', () {
    final byTag = filterAndSortDocuments(
      docs,
      const LibraryQuery(tag: 'finance'),
    );
    expect(byTag.map((d) => d.id).toSet(), {'a', 'c'});

    final bySearch = filterAndSortDocuments(
      docs,
      const LibraryQuery(search: 'urgent'),
    );
    expect(bySearch.map((d) => d.id), ['a']);

    final byName = filterAndSortDocuments(
      docs,
      const LibraryQuery(search: 'beta'),
    );
    expect(byName.map((d) => d.id), ['b']);

    // Docs store tag ids; search resolves display names via map.
    final uuidDocs = [
      _doc(id: 'u1', name: 'Tagged file', tags: ['id-urgent']),
      _doc(id: 'u2', name: 'Other', tags: ['id-work']),
    ];
    final byTagName = filterAndSortDocuments(
      uuidDocs,
      const LibraryQuery(search: 'urgent'),
      tagNamesById: const {'id-urgent': 'Urgent', 'id-work': 'Work'},
    );
    expect(byTagName.map((d) => d.id), ['u1']);
  });

  test('sort name / pages / size / dates', () {
    final az = filterAndSortDocuments(
      docs,
      const LibraryQuery(sort: LibrarySort.nameAsc, favoritesFirst: false),
    );
    expect(az.map((d) => d.id), ['a', 'b', 'c']);

    final pages = filterAndSortDocuments(
      docs,
      const LibraryQuery(sort: LibrarySort.pageCount, favoritesFirst: false),
    );
    expect(pages.map((d) => d.id), ['a', 'c', 'b']);

    final size = filterAndSortDocuments(
      docs,
      const LibraryQuery(sort: LibrarySort.fileSize, favoritesFirst: false),
    );
    expect(size.map((d) => d.id), ['a', 'c', 'b']);

    final modified = filterAndSortDocuments(
      docs,
      const LibraryQuery(
        sort: LibrarySort.recentlyModified,
        favoritesFirst: false,
      ),
    );
    expect(modified.map((d) => d.id), ['b', 'a', 'c']);
  });

  test('favoritesFirst pins starred docs', () {
    final list = filterAndSortDocuments(
      docs,
      const LibraryQuery(sort: LibrarySort.nameAsc, favoritesFirst: true),
    );
    expect(list.first.id, 'a');
  });

  test('collectAllTags skips trash', () {
    final tags = collectAllTags(docs);
    expect(tags, containsAll(['finance', 'urgent', 'personal']));
    expect(tags.length, 3);
  });

  test('entering trash clears favorites, search, and tag', () {
    final c = LibraryQueryController();
    c.setFavoritesOnly(true);
    c.setSearch('invoice');
    c.setTag('finance');
    c.setFolder('work');
    c.setShowTrash(true);
    expect(c.state.showTrash, isTrue);
    expect(c.state.favoritesOnly, isFalse);
    expect(c.state.search, isEmpty);
    expect(c.state.tag, isNull);
    expect(c.state.folderId, isNull);
  });

  test('filterConvertOutputs respects favorite and tag', () {
    final files = [
      ConvertOutput(
        path: '/a.pdf',
        name: 'a.pdf',
        modifiedAt: DateTime(2026, 8, 1),
        bytes: 10,
        isFavorite: true,
        tags: const ['work'],
      ),
      ConvertOutput(
        path: '/b.pdf',
        name: 'b.pdf',
        modifiedAt: DateTime(2026, 8, 2),
        bytes: 20,
      ),
    ];
    expect(
      filterConvertOutputs(
        files,
        const LibraryQuery(favoritesOnly: true),
      ).map((c) => c.name),
      ['a.pdf'],
    );
    expect(
      filterConvertOutputs(
        files,
        const LibraryQuery(tag: 'work'),
      ).map((c) => c.name),
      ['a.pdf'],
    );
    expect(
      filterConvertOutputs(files, const LibraryQuery(showTrash: true)),
      isEmpty,
    );
  });
}

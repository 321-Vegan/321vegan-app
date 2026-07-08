import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/helper.dart';
import 'package:vegan_app/models/e_number.dart';
import 'package:vegan_app/widgets/shared/search_empty_state.dart';

class AdditivesPage extends StatefulWidget {
  const AdditivesPage({super.key});

  @override
  AdditivesPageState createState() => AdditivesPageState();
}

class AdditivesPageState extends State<AdditivesPage> {
  List<ENumberItem> eNumbers = [];
  List<ENumberItem> filteredENumbers = [];
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await _loadENumbers();
    await _loadLastSearch();
  }

  Future<void> _loadLastSearch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final lastSearch = prefs.getString('lastSearch');
    if (lastSearch != null) {
      searchController.text = lastSearch;
      _searchENumber(lastSearch);
    }
  }

  Future<void> _loadENumbers() async {
    final String jsonData =
        await rootBundle.loadString('lib/assets/scanner/e_numbers.json');
    final jsonItems = jsonDecode(jsonData)['items'] as List;

    if (!mounted) return;

    setState(() {
      eNumbers = jsonItems
          .map((item) => ENumberItem.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  void _searchENumber(String query) {
    Helper.saveLastSearch(query);

    if (query.isEmpty) {
      if (mounted) setState(() => filteredENumbers = []);
      return;
    }

    final normalizedQuery = query.toLowerCase();
    final isENumberSearch = RegExp(r'^(e?\d+[a-zA-Z]*)$', caseSensitive: false)
        .hasMatch(normalizedQuery);

    if (mounted) {
      setState(() {
        filteredENumbers = isENumberSearch
            ? _filterByENumber(normalizedQuery)
            : _filterByName(normalizedQuery);
      });
    }
  }

  List<ENumberItem> _filterByENumber(String query) {
    final exactMatches =
        eNumbers.where((e) => e.eNumber.toLowerCase() == query).toList();
    final partialMatches = eNumbers
        .where((e) =>
            e.eNumber.toLowerCase().contains(query) &&
            e.eNumber.toLowerCase() != query)
        .toList();
    return [...exactMatches, ...partialMatches];
  }

  List<ENumberItem> _filterByName(String query) {
    return eNumbers.where((e) => e.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextFormField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText:
                      'Rechercher un additif (par ex. e200, e120, carmin, lactate, ...)',
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: _searchENumber,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filteredENumbers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 32.0),
                      child: SearchEmptyState(),
                    )
                  : _buildENumberList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildENumberList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filteredENumbers.length,
      itemBuilder: (context, index) {
        final eNumber = filteredENumbers[index];
        return Card(
          color: _chooseColorByState(eNumber.state),
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
          child: eNumber.description.isNotEmpty
              ? ExpansionTile(
                  title: Text(
                    '${eNumber.name} (${eNumber.eNumber})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    eNumber.state.toCapitalized(),
                    style: const TextStyle(fontSize: 14),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                      child: Text(
                        eNumber.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                )
              : ListTile(
                  title: Text(
                    '${eNumber.name} (${eNumber.eNumber})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    eNumber.state.toCapitalized(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
        );
      },
    );
  }

  Color? _chooseColorByState(String state) {
    switch (state) {
      case "vegan":
        return Colors.green[100];
      case "carniste":
        return Colors.red[100];
      case "Ça dépend":
        return Colors.yellow[100];
      default:
        return Colors.grey[300];
    }
  }
}

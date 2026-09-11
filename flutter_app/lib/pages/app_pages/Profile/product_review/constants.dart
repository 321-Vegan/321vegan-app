import 'package:flutter/material.dart';

const productReviewStatuses = [
  (value: 'NOT_FOUND', label: 'Inconnu', color: Color(0xFF616161)),
  (value: 'MAYBE_VEGAN', label: 'Maybe vegan', color: Color.fromARGB(255, 250, 146, 90)),
  (value: 'VEGAN', label: 'Vegan', color: Color(0xFF2E7D32)),
  (value: 'NON_VEGAN', label: 'Non vegan', color: Color(0xFFC62828)),
];

const productStates = [
  (value: 'CREATED', label: 'À vérifier', color: Color(0xFF757575)),
  (value: 'NEED_CONTACT', label: 'À contacter', color: Color(0xFFF57C00)),
  (value: 'TO_INVESTIGATE', label: 'Cosmétique à vérif', color: Color(0xFF00838F)),
  (value: 'WAITING_PUBLISH', label: 'À publier', color: Color(0xFF4527A0)),
];

// Product type — food / cosmetic / household cleaner.
const productTypes = [
  (value: 'FOOD', label: 'Alimentaire', color: Color(0xFF616161)),
  (value: 'COSMETIC', label: 'Cosmétique', color: Color(0xFF616161)),
  (value: 'HOUSEHOLD', label: 'Entretien', color: Color(0xFF616161)),
];

const nonVeganIngredients = [
  'lait', 'œuf', 'miel', 'viande', 'poisson', 'gélatine',
  'arômes', 'arômes naturels', 'vitamines', "cire d'abeille"
];

const maybeVeganSelectableIngredients = ['arômes', 'arômes naturels', 'vitamines', 'la clarification', 'exhausteurs de goût'];

// Use for highlight in validating products
const nonVeganIngredientKeywords = [
  // Multi-word first (matched before shorter forms by regex length sort)
  "cire d'abeille", "beeswax",
  "graisse animale", "animal fat",
  "lécithine animale", "lecithine animale", "animal lecithin",
  "gélatine de", "gelatine de",
  // Single animal products
  "gélatine", "gelatine",
  "lactosérum", "lactoserum",
  "caséine", "caseine",
  "collagène", "collagene", "collagen",
  "présure", "presure", "rennet",
  "crustacés", "crustaces", "crustaceans",
  "mollusques", "mollusc",
  "cochenille",
  "propolis",
  "anchovies", "anchovy", "anchois",
  "emmental", "fromage", "cheese",
  "beurre", "butter",
  "lactose",
  "lait", "milk",
  "oeuf", "œuf", "egg",
  "poisson", "fish",
  "viande", "meat",
  "boeuf", "beef",
  "poulet", "chicken",
  "bacon",
  "porc", "pork",
  "veau",
  "miel", "honey",
  "crème", "creme", "cream",
  "bonite",
  "collagène", "collagen"
];

const maybeVeganIngredientKeywords = [
  "arômes naturels", "aromes naturels", "natural flavour",
  "arôme naturel", "arome naturel",
  "arômes", "aromes", "arôme", "arome", "flavour",
  "vitamine d", "vitamin d",
  "taurine",
];

// E-numbers definitely non-vegan
const nonVeganENumbers = {
  "E120", "E441", "E542", "E901", "E904", "E910", "E913",
  "E920", "E921", "E966", "E1105",
};

// E-numbers sometimes non-vegan depending on origin
const maybeVeganENumbers = {
  "E170", "E252", "E270", "E322", "E325", "E326", "E327",
  "E422", "E430", "E431", "E432", "E433", "E434", "E435", "E436",
  "E442", "E470A", "E470B",
  "E472A", "E472B", "E472C", "E472D", "E472E", "E472F",
  "E473", "E474", "E475", "E476", "E477", "E478", "E479B",
  "E481", "E482", "E483", "E491", "E492", "E493", "E494", "E495",
  "E570", "E572", "E585", "E627", "E628", "E631", "E633", "E635", "E640",
  "E161G", "E161H", "E161I", "E161J",
};

Color statusColor(String status) =>
    productReviewStatuses.firstWhere((s) => s.value == status,
        orElse: () => (value: '', label: '', color: Colors.grey)).color;

String statusLabel(String status) =>
    productReviewStatuses.firstWhere((s) => s.value == status,
        orElse: () => (value: '', label: status, color: Colors.grey)).label;

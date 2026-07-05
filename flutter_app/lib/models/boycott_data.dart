class BoycottBrand {
  final String match;
  final String display;
  final List<String> aliases;

  const BoycottBrand(this.match, this.display, {this.aliases = const []});
}

class BoycottGroup {
  final String name;
  final String reason;
  final List<String> sources;
  final List<BoycottBrand> brands;

  const BoycottGroup({
    required this.name,
    required this.reason,
    this.sources = const [],
    required this.brands,
  });
}

class BoycottOther {
  final String match;
  final String display;
  final String reason;
  final List<String> sources;
  final List<String> aliases;

  const BoycottOther({
    required this.match,
    required this.display,
    required this.reason,
    this.sources = const [],
    this.aliases = const [],
  });
}

class BoycottMatch {
  final String brandDisplay;
  final String? groupName;
  final String reason;
  final List<String> sources;

  const BoycottMatch({
    required this.brandDisplay,
    this.groupName,
    required this.reason,
    this.sources = const [],
  });
}

class BoycottData {
  static const List<BoycottGroup> groups = [
    BoycottGroup(
      name: 'Mars Group',
      reason:
          'Mars est l\'un des plus grands pollueurs de plastiques au monde.[1] Le groupe a également été lié au travail des enfants dans ses filières cacao en Afrique,[2][3] à de la déforestation et à de la fixation illégale des prix. Mars a continué ses activités en Russie après l\'invasion de l\'Ukraine.[4]',
      sources: [
        'https://brandaudit.breakfreefromplastic.org/brand-audit-2023/',
        'https://www.business-humanrights.org/en/latest-news/nestle-mars-among-firms-named-in-cocoa-child-labour-suit/',
        'https://eu.usatoday.com/story/money/2023/12/01/mars-child-labor-cbs-investigation-findings-response/71769249007/',
        'https://www.business-humanrights.org/en/latest-news/us-co-mars-leases-40000-sqm-warehouse-in-russia-despite-pledges-to-halt-investments/',
      ],
      brands: [
        BoycottBrand('mars', 'Mars'),
        BoycottBrand('dove', 'Dove'),
        BoycottBrand('bounty', 'Bounty'),
        BoycottBrand('ben\'s original', 'Ben\'s Original'),
        BoycottBrand('ben\'s', 'Ben\'s'),
        BoycottBrand('skittles', 'Skittles'),
        BoycottBrand('m&m\'s', 'M&M\'s'),
        BoycottBrand('snickers', 'Snickers'),
        BoycottBrand('twix', 'Twix'),
        BoycottBrand('milky way', 'Milky Way', aliases: ['milkyway']),
        BoycottBrand('maltesers', 'Maltesers'),
        BoycottBrand('starburst', 'Starburst'),
        BoycottBrand('extra', 'Extra'),
        BoycottBrand('orbit', 'Orbit'),
        BoycottBrand('wrigley\'s', 'Wrigley\'s', aliases: ['wrigleys']),
        BoycottBrand('ebly', 'Ebly'),
        BoycottBrand('suzi wan', 'Suzi Wan'),
      ],
    ),
    BoycottGroup(
      name: 'Carrefour Group',
      reason:
          'Les chaînes d\'approvisionnement de Carrefour ont été liées à de l\'esclavage moderne,[1] de la maltraitance animale et de la déforestation illégale en Amazonie.[2] L\'enseigne a aussi discriminé des clients LGBT[3] Carrefour figure sur la liste de boycott du mouvement BDS depuis 2022 : l\'enseigne a conclu un partenariat de franchise avec Yenot Bitan, une chaîne israélienne dont des magasins sont implantés dans des colonies illégales en Cisjordanie et à Jérusalem-Est occupée.[5]',
      sources: [
        'https://web.archive.org/web/20200428183820/https://www.theguardian.com/global-development/2014/jun/10/supermarket-prawns-thailand-produced-slave-labour',
        'https://www.lefigaro.fr/flash-eco/deforestation-en-amazonie-carrefour-interpelle-sur-ses-fournisseurs-20220905',
        'https://web.archive.org/web/20090829214838/http://portal.prefeitura.sp.gov.br/noticias/coordenadorias/diversidade_sexual/2008/09/0006',
        'https://bdsmovement.net/boycott-carrefour',
      ],
      brands: [
        BoycottBrand('carrefour', 'Carrefour'),
        BoycottBrand('reflets de france', 'Reflets de France'),
        BoycottBrand('tex', 'Tex'),
        BoycottBrand('grand jury', 'Grand Jury'),
      ],
    ),
    BoycottGroup(
      name: 'Coca-Cola Company',
      reason:
          'Coca-Cola est le premier pollueur plastique mondial,[1][2] produisant 200 000 bouteilles plastique par minute. L\'entreprise épuise par ailleurs les nappes phréatiques dans des régions déjà frappées par la sécheresse.[3] Le groupe Coca-Cola (via la marque Monster) sponsorise des sports cruels pour les animaux tels que le rodéo. C\'est aussi un soutien moral et financer d\'Israël.[4]',
      sources: [
        'https://www.forbes.com/sites/trevornace/2019/10/29/coca-cola-named-the-worlds-most-polluting-brand-in-plastic-waste-audit/',
        'https://www.indiatimes.com/news/india/pepsico-was-the-biggest-plastic-polluter-in-india-in-2022-coca-cola-globally-584817.html',
        'https://waronwant.org/news-analysis/coca-cola-drinking-world-dry',
        'https://www.bdsfrance.org/coca-cola-etancher-la-soif-des-soldats-genocidaires-disrael/',
      ],
      brands: [
        BoycottBrand('coca-cola', 'Coca-Cola', aliases: ['coca cola']),
        BoycottBrand('fanta', 'Fanta'),
        BoycottBrand('sprite', 'Sprite'),
        BoycottBrand('tropico', 'Tropico'),
        BoycottBrand('minute maid', 'Minute Maid'),
        BoycottBrand('powerade', 'Powerade'),
        BoycottBrand('monster', 'Monster'),
        BoycottBrand('fuze tea', 'Fuze Tea', aliases: ['fuzetea']),
        BoycottBrand('innocent', 'Innocent'),
        BoycottBrand('vitaminwater', 'Vitaminwater'),
      ],
    ),
    BoycottGroup(
      name: 'PepsiCo',
      reason:
          'PepsiCo est l\'un des plus grands pollueurs plastiques au monde[1] et contribue à l\'épuisement des ressources en eau dans des zones en stress hydrique.[2] PepsiCo est aussi copropriétaire de Sabra, en partenariat avec le groupe israélien Strauss, dont une division finance directement l\'armée israélienne.[3]',
      sources: [
        'https://www.fastcompany.com/90425011/coca-cola-nestle-and-pepsico-are-the-worlds-biggest-plastic-polluters-again',
        'https://www.theguardian.com/environment/2017/jul/21/pepsico-unilever-and-nestle-accused-of-complicity-in-illegal-rainforest-destruction',
        'https://fr-cjpme.nationbuilder.com/fs_239'
      ],
      brands: [
        BoycottBrand('pepsico', 'PepsiCo'),
        BoycottBrand('pepsi', 'Pepsi'),
        BoycottBrand('sabra', 'Sabra'),
        BoycottBrand('lay\'s', 'Lay\'s', aliases: ['lays']),
        BoycottBrand('quaker', 'Quaker'),
        BoycottBrand('doritos', 'Doritos'),
        BoycottBrand('cheetos', 'Cheetos'),
        BoycottBrand('tostitos', 'Tostitos'),
        BoycottBrand('bénénuts', 'Bénénuts', aliases: ['benenuts']),
        BoycottBrand('rockstar', 'Rockstar'),
        BoycottBrand('mountain dew', 'Mountain Dew', aliases: ['montain dew']),
        BoycottBrand('gatorade', 'Gatorade'),
        BoycottBrand('mirinda', 'Mirinda'),
        BoycottBrand('7up', '7UP'),
        BoycottBrand('tropicana', 'Tropicana'),
        BoycottBrand('lipton', 'Lipton'),
        BoycottBrand('sodastream', 'Sodastream'),
      ],
    ),
    BoycottGroup(
      name: 'Nestlé',
      reason:
          'Le groupe Nestlé est mis en cause pour travail des enfants dans ses filières cacao en Afrique de l\'Ouest,[1][2] et pour avoir remis en question le droit à l\'eau potable en cherchant à privatiser des sources naturelles dans des régions vulnérables.[3] En France, ils ont fait de l\'enfouissement illégal de déchets, menant à des montagnes de plastiques.[4]',
      sources: [
        'https://web.archive.org/web/20081226141935/http://news.bbc.co.uk/1/hi/world/africa/1272522.stm',
        'https://web.archive.org/web/20090114115945/http://news.bbc.co.uk/2/hi/africa/1311982.stm',
        'https://web.archive.org/web/20170629043128/http://www.thenational.ae/arts-culture/the-human-rights-and-wrongs-of-nestl-and-water-for-all',
        'https://www.lemonde.fr/planete/article/2026/03/26/nestle-poursuivi-pour-decharges-sauvages-pres-de-vittel-750-000-euros-d-amende-requis-et-remise-en-etat-exigee_6674415_3244.html'
      ],
      brands: [
        BoycottBrand('nestlé', 'Nestlé', aliases: ['nestle']),
        BoycottBrand('garden gourmet', 'Garden Gourmet'),
        BoycottBrand('maggi', 'Maggi'),
        BoycottBrand('nescafé', 'Nescafé', aliases: ['nescafe']),
        BoycottBrand('nespresso', 'Nespresso'),
        BoycottBrand('nesquik', 'Nesquik', aliases: ['nesquick']),
        BoycottBrand('kit kat', 'Kit Kat', aliases: ['kitkat']),
        BoycottBrand('perrier', 'Perrier'),
        BoycottBrand('vittel', 'Vittel', aliases: ['vitel']),
        BoycottBrand('san pellegrino', 'San Pellegrino'),
      ],
    ),
    BoycottGroup(
      name: 'Unilever',
      reason:
          'Quand Ben & Jerry\'s a voulu cesser ses ventes dans les colonies israéliennes illégales, Unilever a vendu la marque à son franchisé israélien pour court-circuiter cette décision.[1] Le groupe s\'est aussi opposé à une loi contre le plastique à usage unique,[2] et ses chaînes d\'approvisionnement ont été liées à de la déforestation et du travail des enfants.[3]',
      sources: [
        'https://www.aljazeera.com/news/2022/6/30/unilever-sells-benjerrys-ice-cream-to-local-licensee-in-israel',
        'https://www.reuters.com/investigates/special-report/global-plastic-unilever/',
        'https://web.archive.org/web/20180423210624/https://www.amnesty.org/en/documents/asa21/5184/2016/en/',
      ],
      brands: [
        BoycottBrand('marmite', 'Marmite'),
        BoycottBrand('unilever', 'Unilever'),
        BoycottBrand('knorr', 'Knorr'),
        BoycottBrand('maïzena', 'Maïzena', aliases: ['maizena']),
        BoycottBrand('maille', 'Maille'),
        BoycottBrand('amora', 'Amora'),
        BoycottBrand('hellmann\'s', 'Hellmann\'s', aliases: ['hellmanns']),
        BoycottBrand('ben & jerry\'s', 'Ben & Jerry\'s',
            aliases: ['ben & jerrys', 'ben&jerry\'s']),
        BoycottBrand('éléphant', 'Éléphant',
            aliases: ['elephant', 'eléphant']),
        BoycottBrand('the vegetarian butcher', 'The Vegetarian Butcher'),
      ],
    ),
    BoycottGroup(
      name: 'L\'Oréal',
      reason:
          'L\'Oréal dispose de centres de R&D et d\'usines de production en Israël, contribuant directement à son économie.[1][2] Le groupe vend aussi en Chine où les tests sur les animaux sont légalement obligatoires, ce qui le contraint à cautionner cette pratique malgré ses déclarations contraires.[3]',
      sources: [
        'https://brusselsmorning.com/does-loreal-support-israel-business-activities-boycotts/75552/',
        'https://www.bbc.com/news/world-middle-east-68172560',
        'https://www.crueltyfreekitty.com/brands/loreal/'
      ],
      brands: [
        BoycottBrand('l\'oréal', 'L\'Oréal',
            aliases: ['l\'oreal', 'loréal', 'loreal']),
        BoycottBrand('garnier', 'Garnier'),
        BoycottBrand('maybelline', 'Maybelline'),
        BoycottBrand('nyx', 'NYX'),
        BoycottBrand('lancôme', 'Lancôme', aliases: ['lancome']),
        BoycottBrand('la roche-posay', 'La Roche-Posay',
            aliases: ['la roche posay', 'laroche-posay']),
        BoycottBrand('cerave', 'CeraVe'),
        BoycottBrand('vichy', 'Vichy'),
        BoycottBrand('kérastase', 'Kérastase', aliases: ['kerastase']),
        BoycottBrand('redken', 'Redken'),
        BoycottBrand('kiehl\'s', 'Kiehl\'s', aliases: ['kiehls']),
      ],
    ),
    BoycottGroup(
      name: 'Lidl',
      reason:
          'Lidl a espionné massivement ses employés, collectant des données très personnelles comme leurs cycles menstruels, leur situation financière ou leur vie sentimentale.[1] L\'enseigne ferme délibérément les magasins où des tentatives de syndicalisation émergent,[2] et a été mise en cause pour maltraitance animale dans ses filières d\'approvisionnement.[3] Ils ont aussi été surpris plusieurs fois à mal étiquetter des produits venant d\'Israël pour éviter leur boycott.[4]',
      sources: [
        'https://www.theguardian.com/world/2008/mar/27/germany.supermarkets',
        'https://www.mashed.com/94133/untold-truth-lidl/',
        'https://www.l214.com/stop-cruaute/lidl/',
        'https://www.webdo.tn/fr/actualite/international/scandale-en-france-des-produits-israeliens-avec-de-faux-etiquetages-pour-contourner-le-boycott/210184/'
      ],
      brands: [
        BoycottBrand('lidl', 'Lidl'),
        BoycottBrand('snack day', 'Snack Day'),
        BoycottBrand('freshona', 'Freshona'),
        BoycottBrand('favorina', 'Favorina'),
        BoycottBrand('deluxe', 'Deluxe'),
        BoycottBrand('cien', 'Cien'),
        BoycottBrand('solevita', 'Solevita'),
        BoycottBrand('sondey', 'Sondey'),
        BoycottBrand('vemondo', 'Vemondo'),
        BoycottBrand('crownfield', 'Crownfield'),
      ],
    ),
    BoycottGroup(
      name: 'Mondelez',
      reason:
          'Mondelez a détruit des dizaines de milliers d\'hectares d\'habitat d\'orangs-outans[1] et continue de recourir au travail des enfants dans ses filières cacao, malgré ses promesses répétées d\'y mettre fin.[2] Ils sont aussi sur la liste BDS pour leur soutien à Israël.[3]',
      sources: [
        'https://www.independent.co.uk/environment/orangutans-palm-oil-habitat-rainforest-cadbury-mondelez-oreos-indonesia-greenpeace-a8630801.html',
        'https://www.theguardian.com/law/2022/apr/03/cadbury-faces-fresh-accusations-of-child-labour-on-cocoa-farms-in-ghana',
        'https://bdscoalition.ca/2025/03/14/mondelez-international-supporter-of-apartheid/',
      ],
      brands: [
        BoycottBrand('mondelez', 'Mondelez'),
        BoycottBrand('oreo', 'Oreo'),
        BoycottBrand('milka', 'Milka'),
        BoycottBrand('toblerone', 'Toblerone'),
        BoycottBrand('cadbury', 'Cadbury'),
        BoycottBrand('belvita', 'BelVita'),
        BoycottBrand('côte d\'or', 'Côte d\'Or', aliases: ['cote d\'or']),
        BoycottBrand('lu', 'LU'),
        BoycottBrand('prince', 'Prince'),
        BoycottBrand('mikado', 'Mikado'),
        BoycottBrand('belin', 'Belin'),
        BoycottBrand('heudebert', 'Heudebert'),
        BoycottBrand('sour patch', 'Sour Patch'),
      ],
    ),
    BoycottGroup(
      name: 'Danone',
      reason:
          'Danone a trompé des mères sur les vertus de ses laits infantiles pour booster ses ventes,[1] et versé des pots-de-vin à des sages-femmes pour promouvoir ses formules.[2] Le groupe a aussi été épinglé pour l\'assèchement de sources naturelles près de ses usines[3] et une pollution plastique massive dans de nombreux pays.[4]',
      sources: [
        'https://web.archive.org/web/20201112021537/http://www.independent.co.uk/news/uk/home-news/after-nestle-aptamil-manufacturer-danone-now-hit-breast-milk-scandal-8679226.html',
        'https://web.archive.org/web/20160502150942/http://www.theguardian.com/world/2013/feb/15/babies-health-formula-indonesia-breastfeeding',
        'https://www.euronews.com/2023/06/15/french-region-on-the-brink-of-desertification-says-hydrobiologist',
        'https://www.theguardian.com/environment/2023/jan/10/activists-sue-french-food-firm-danone-plastics-footprint',
      ],
      brands: [
        BoycottBrand('danone', 'Danone'),
        BoycottBrand('materne', 'Materne'),
        BoycottBrand('alpro', 'Alpro'),
        BoycottBrand('volvic', 'Volvic'),
        BoycottBrand('evian', 'Evian'),
        BoycottBrand('bledina', 'Blédina'),
      ],
    ),
    BoycottGroup(
      name: 'Ferrero',
      reason:
          'Ferrero est mis en cause pour le recours persistant au travail des enfants dans ses filières cacao en Afrique de l\'Ouest, malgré des engagements répétés à y mettre fin.[1]',
      sources: [
        'https://www.washingtonpost.com/graphics/2019/business/ferrero-chocolate-cocoa-child-labor/',
      ],
      brands: [
        BoycottBrand('ferrero', 'Ferrero'),
        BoycottBrand('nutella', 'Nutella'),
        BoycottBrand('kinder', 'Kinder'),
        BoycottBrand('tic tac', 'Tic Tac', aliases: ['tictac']),
        BoycottBrand('raffaello', 'Raffaello'),
        BoycottBrand('mon chéri', 'Mon Chéri', aliases: ['mon cheri']),
        BoycottBrand('bueno', 'Bueno'),
      ],
    ),
  ];

  static const List<BoycottOther> others = [
    BoycottOther(
      match: 'starbucks',
      display: 'Starbucks',
      reason:
          'Starbucks pratique l\'évasion fiscale à grande échelle,[1] a privé des agriculteurs éthiopiens de revenus qui leur étaient dus,[2] applique des inégalités salariales selon l\'origine de ses employés et mène des campagnes antisyndicales agressives.[3] La chaîne a par ailleurs collaboré étroitement avec l\'Anti-Union League.[3]',
      sources: [
        'https://web.archive.org/web/20160210024015/http://uk.reuters.com/article/us-britain-starbucks-tax-idUKBRE89E0EX20121015',
        'https://web.archive.org/web/20191221001509/https://www.oxfamamerica.org/press/starbucks-opposes-ethiopia-coffee-trademark-plan/',
        'https://web.archive.org/web/20220215175957/https://www.theguardian.com/business/2021/nov/23/starbucks-aggressive-anti-union-effort-new-york-stores-organize',
      ],
    ),
    BoycottOther(
      match: 'osem',
      display: 'Osem',
      reason:
          'Osem est l\'une des plus grandes entreprises alimentaires d\'Israël, désormais filiale du groupe Nestlé. Elle opère principalement en Israël et contribue directement à son économie.',
    ),
    BoycottOther(
      match: 'ahava',
      display: 'Ahava',
      reason:
          'Ahava est une marque de cosmétiques israélienne dont le site de production est installé dans la colonie illégale de Mitzpe Shalem, en Cisjordanie occupée. Acheter Ahava finance directement une activité implantée sur des terres palestiniennes.',
    ),
    BoycottOther(
      match: 'oatly',
      display: 'Oatly',
      reason:
          'Oatly a accepté un investissement de 200 millions de dollars du fonds Blackstone.[1] Le fondateur de Blackstone, Stephen Schwarzman, est un important donateur et soutien de la politique américaine pro-israélienne.',
      sources:[
      'https://www.retaildetail.be/fr/news/food/le-lait-davoine-oatly-menace-de-boycott/'
      ]
    ),
    BoycottOther(
      match: 'redefine meat',
      display: 'Redefine Meat',
      reason:
          'Redefine Meat est une entreprise de viande végétale fondée et basée en Israël. Acheter ses produits contribue directement à l\'économie israélienne.',
    ),
    BoycottOther(
      match: 'hénaff',
      display: 'Hénaff',
      reason:
          'Hénaff est une entreprise dont le cœur de métier est la viande : pâtés, rillettes et charcuterie. Son modèle économique repose intégralement sur l\'exploitation animale, ce qui le rend fondamentalement incompatible avec les valeurs du véganisme.',
      aliases: ['henaff'],
    ),
    BoycottOther(
      match: 'red bull',
      display: 'Red Bull',
      reason:
          'RedBull finance des tests extrêmement cruels sur les animaux via sa fondation Wings For Life. Certains tests consistent par exemple à briser la colonne vertébrale de rat pour étudier l\'effet d\'un médicament. Ils ne s\'en cachent pas, et les détails peuvent être trouvés directement sur le site de Redbull et de Wings for life.',
      aliases: ['redbull'],
    ),
    BoycottOther(
      match: 'maayane',
      display: 'Maayane',
      reason:
          'Maayane est une marque israélienne commercialisant des produits alimentaires. Acheter ses produits contribue directement à l\'économie israélienne.',
    ),
  ];

  static BoycottMatch? findBrand(String brandInput) {
    final brandList =
        brandInput.split(',').map((e) => e.trim().toLowerCase()).toList();

    for (final brand in brandList) {
      for (final group in groups) {
        for (final b in group.brands) {
          if (b.match == brand || b.aliases.contains(brand)) {
            return BoycottMatch(
              brandDisplay: b.display,
              groupName: group.name,
              reason: group.reason,
              sources: group.sources,
            );
          }
        }
      }
      for (final other in others) {
        if (other.match == brand || other.aliases.contains(brand)) {
          return BoycottMatch(
            brandDisplay: other.display,
            groupName: null,
            reason: other.reason,
            sources: other.sources,
          );
        }
      }
    }
    return null;
  }
}

/// Catalogo dei modelli conosciuti, con una fascia di prezzo dell'usato
/// (in euro) usata come stima iniziale. Le stime vengono poi corrette dallo
/// storico dei prezzi che l'app raccoglie.
///
/// I prezzi sono indicativi (mercato dell'usato europeo, condizioni buone,
/// senza scatola e garanzia) e vanno aggiornati nel tempo.
library;

class Brand {
  final String id;
  final String name;

  /// Parole che identificano la marca (minuscolo, cercate come parola intera).
  final List<String> names;

  /// Errori di battitura frequenti: chi li usa riceve meno visite.
  final List<String> misspellings;

  /// Fascia generica quando il modello non è riconosciuto.
  final double floor;
  final double ceiling;

  /// Costo indicativo di una revisione.
  final double serviceCost;

  const Brand({
    required this.id,
    required this.name,
    required this.names,
    required this.misspellings,
    required this.floor,
    required this.ceiling,
    required this.serviceCost,
  });
}

/// Quanto è facile rivendere il modello.
enum Liquidity { alta, media, bassa }

class WatchModel {
  final String id;
  final String brandId;
  final String name;

  /// Parole o referenze che identificano il modello (minuscolo).
  final List<String> aliases;
  final double low;
  final double high;
  final Liquidity liquidity;

  const WatchModel({
    required this.id,
    required this.brandId,
    required this.name,
    required this.aliases,
    required this.low,
    required this.high,
    this.liquidity = Liquidity.media,
  });

  double get mid => (low + high) / 2;
}

const brands = <Brand>[
  Brand(
    id: 'seiko',
    name: 'Seiko',
    names: ['seiko'],
    misspellings: ['seico', 'saiko', 'seyko', 'sieko', 'seikko'],
    floor: 60,
    ceiling: 250,
    serviceCost: 120,
  ),
  Brand(
    id: 'citizen',
    name: 'Citizen',
    names: ['citizen'],
    misspellings: ['citizien', 'citzen', 'citisen', 'cittizen', 'citizens', 'sitizen'],
    floor: 40,
    ceiling: 180,
    serviceCost: 110,
  ),
  Brand(
    id: 'omega',
    name: 'Omega',
    names: ['omega'],
    misspellings: ['omgea', 'omaga', 'omegha', 'omeag', 'oméga'],
    floor: 400,
    ceiling: 1500,
    serviceCost: 450,
  ),
  Brand(
    id: 'zenith',
    name: 'Zenith',
    names: ['zenith'],
    misspellings: ['zenit', 'zeniht', 'zenth', 'zentih', 'zenitt'],
    floor: 350,
    ceiling: 1500,
    serviceCost: 450,
  ),
  Brand(
    id: 'rado',
    name: 'Rado',
    names: ['rado'],
    misspellings: ['raddo', 'radò'],
    floor: 150,
    ceiling: 500,
    serviceCost: 250,
  ),
];

const models = <WatchModel>[
  // ---- Seiko ----
  WatchModel(id: 'seiko_skx', brandId: 'seiko', name: 'Seiko SKX007/009/013',
      aliases: ['skx007', 'skx009', 'skx013', 'skx 007', 'skx 009', 'skx'],
      low: 250, high: 450, liquidity: Liquidity.alta),
  WatchModel(id: 'seiko_alpinist', brandId: 'seiko', name: 'Seiko Alpinist',
      aliases: ['alpinist', 'sarb017', 'spb121', 'spb117', 'spb155'],
      low: 450, high: 700, liquidity: Liquidity.alta),
  WatchModel(id: 'seiko_62mas', brandId: 'seiko', name: 'Seiko Prospex 62MAS',
      aliases: ['62mas', 'spb143', 'spb147', 'spb149'],
      low: 650, high: 950, liquidity: Liquidity.alta),
  WatchModel(id: 'seiko_samurai', brandId: 'seiko', name: 'Seiko Samurai',
      aliases: ['samurai', 'srpb09', 'srpb51', 'srpf'],
      low: 220, high: 380),
  WatchModel(id: 'seiko_turtle', brandId: 'seiko', name: 'Seiko Turtle',
      aliases: ['turtle', 'srp777', 'srp775', 'srpe93', 'srpe'],
      low: 220, high: 350, liquidity: Liquidity.alta),
  WatchModel(id: 'seiko_cocktail', brandId: 'seiko', name: 'Seiko Presage Cocktail',
      aliases: ['cocktail', 'srpb43', 'srpb41', 'presage'],
      low: 200, high: 330),
  WatchModel(id: 'seiko_5sports', brandId: 'seiko', name: 'Seiko 5 Sports',
      aliases: ['seiko 5 sports', '5 sports', 'srpd', 'srpk'],
      low: 110, high: 190),
  WatchModel(id: 'seiko_6139', brandId: 'seiko', name: 'Seiko 6139 / 6138 crono vintage',
      aliases: ['6139', '6138', 'pogue'],
      low: 300, high: 700, liquidity: Liquidity.media),
  WatchModel(id: 'seiko_grand', brandId: 'seiko', name: 'Grand Seiko',
      aliases: ['grand seiko'],
      low: 2500, high: 5000, liquidity: Liquidity.media),

  // ---- Citizen ----
  WatchModel(id: 'citizen_fugu', brandId: 'citizen', name: 'Citizen Promaster NY0040 "Fugu"',
      aliases: ['ny0040', 'fugu', 'ny0085', 'ny0080'],
      low: 180, high: 320, liquidity: Liquidity.alta),
  WatchModel(id: 'citizen_bn0150', brandId: 'citizen', name: 'Citizen Promaster Eco-Drive BN0150',
      aliases: ['bn0150', 'bn0151', 'bn0156'],
      low: 110, high: 190),
  WatchModel(id: 'citizen_tsuyosa', brandId: 'citizen', name: 'Citizen Tsuyosa',
      aliases: ['tsuyosa', 'nj0150', 'nj0151'],
      low: 190, high: 290, liquidity: Liquidity.alta),
  WatchModel(id: 'citizen_series8', brandId: 'citizen', name: 'Citizen Series 8',
      aliases: ['series 8', 'series8', 'nb6000', 'nb6010'],
      low: 500, high: 800),
  WatchModel(id: 'citizen_bullhead', brandId: 'citizen', name: 'Citizen Bullhead / 8110 vintage',
      aliases: ['bullhead', '8110'],
      low: 200, high: 450),
  WatchModel(id: 'citizen_attesa', brandId: 'citizen', name: 'Citizen Attesa',
      aliases: ['attesa'],
      low: 300, high: 600, liquidity: Liquidity.bassa),
  WatchModel(id: 'citizen_bm8180', brandId: 'citizen', name: 'Citizen BM8180',
      aliases: ['bm8180'],
      low: 80, high: 140),

  // ---- Omega ----
  WatchModel(id: 'omega_moonswatch', brandId: 'omega', name: 'Omega x Swatch MoonSwatch',
      aliases: ['moonswatch', 'moon swatch', 'swatch', 'mission to', 'mission on'],
      low: 170, high: 280, liquidity: Liquidity.alta),
  WatchModel(id: 'omega_moonwatch', brandId: 'omega', name: 'Omega Speedmaster Professional',
      aliases: ['moonwatch', 'speedmaster professional', '311.30.42.30', '310.30.42.50',
          '3570.50', '3572.50', '145.022', '145022'],
      low: 4300, high: 6000, liquidity: Liquidity.alta),
  WatchModel(id: 'omega_reduced', brandId: 'omega', name: 'Omega Speedmaster Reduced',
      aliases: ['reduced', '3510.50', '3539.50', '3510.80'],
      low: 1700, high: 2400, liquidity: Liquidity.alta),
  WatchModel(id: 'omega_smp', brandId: 'omega', name: 'Omega Seamaster Diver 300M',
      aliases: ['seamaster 300', '300m', 'diver 300', '2531.80', '2254.50', '2220.80',
          '210.30.42', '2541.80'],
      low: 2000, high: 4000, liquidity: Liquidity.alta),
  WatchModel(id: 'omega_aquaterra', brandId: 'omega', name: 'Omega Seamaster Aqua Terra',
      aliases: ['aqua terra', 'aquaterra', '220.10.41', '2503.80', '2504.50'],
      low: 2800, high: 4500),
  WatchModel(id: 'omega_po', brandId: 'omega', name: 'Omega Planet Ocean',
      aliases: ['planet ocean', '2200.50', '232.30.42', '215.30.44'],
      low: 3300, high: 5500),
  WatchModel(id: 'omega_constellation', brandId: 'omega', name: 'Omega Constellation',
      aliases: ['constellation', 'pie pan', 'piepan'],
      low: 800, high: 2500, liquidity: Liquidity.media),
  WatchModel(id: 'omega_deville', brandId: 'omega', name: 'Omega De Ville',
      aliases: ['de ville', 'deville'],
      low: 500, high: 1800, liquidity: Liquidity.bassa),
  WatchModel(id: 'omega_vintage', brandId: 'omega', name: 'Omega Seamaster / Genève vintage',
      aliases: ['geneve', 'genève', 'seamaster vintage', 'seamaster cosmic', 'cosmic',
          'seamaster de ville', 'calibro 565', 'cal. 565'],
      low: 400, high: 1200, liquidity: Liquidity.media),

  // ---- Zenith ----
  WatchModel(id: 'zenith_elprimero', brandId: 'zenith', name: 'Zenith El Primero / Chronomaster',
      aliases: ['el primero', 'elprimero', 'chronomaster'],
      low: 4000, high: 7500, liquidity: Liquidity.media),
  WatchModel(id: 'zenith_defy', brandId: 'zenith', name: 'Zenith Defy',
      aliases: ['defy'],
      low: 2800, high: 6000, liquidity: Liquidity.media),
  WatchModel(id: 'zenith_pilot', brandId: 'zenith', name: 'Zenith Pilot',
      aliases: ['pilot', 'type 20', 'type20'],
      low: 3200, high: 5500, liquidity: Liquidity.media),
  WatchModel(id: 'zenith_elite', brandId: 'zenith', name: 'Zenith Elite',
      aliases: ['elite'],
      low: 2000, high: 3500, liquidity: Liquidity.bassa),
  WatchModel(id: 'zenith_vintage', brandId: 'zenith', name: 'Zenith vintage (anni 50-70)',
      aliases: ['zenith automatic', 'zenith carica manuale', 'cal. 2552', '2552', 'autosport'],
      low: 400, high: 1300, liquidity: Liquidity.media),

  // ---- Rado ----
  WatchModel(id: 'rado_captaincook', brandId: 'rado', name: 'Rado Captain Cook',
      aliases: ['captain cook', 'capitan cook'],
      low: 1200, high: 1900, liquidity: Liquidity.alta),
  WatchModel(id: 'rado_hyperchrome', brandId: 'rado', name: 'Rado HyperChrome',
      aliases: ['hyperchrome', 'hyper chrome'],
      low: 600, high: 1100),
  WatchModel(id: 'rado_true', brandId: 'rado', name: 'Rado True / Ceramica',
      aliases: ['true thinline', 'thinline', 'rado true', 'ceramica', 'integral'],
      low: 450, high: 1100),
  WatchModel(id: 'rado_centrix', brandId: 'rado', name: 'Rado Centrix',
      aliases: ['centrix'],
      low: 350, high: 700),
  WatchModel(id: 'rado_diastar', brandId: 'rado', name: 'Rado DiaStar',
      aliases: ['diastar', 'dia star', 'diastar original'],
      low: 250, high: 650, liquidity: Liquidity.media),
];

Brand? brandById(String id) {
  for (final b in brands) {
    if (b.id == id) return b;
  }
  return null;
}

WatchModel? modelById(String id) {
  for (final m in models) {
    if (m.id == id) return m;
  }
  return null;
}

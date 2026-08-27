Map<String, dynamic> demoWorldState(String locale) {
  return switch (locale) {
    'fr' => const {
        'title': 'La porte du wyrm',
        'setting': 'Une cave sous une taverne, au pied d une colline ancienne.',
        'tone': 'aventure courte, tension, cliffhanger',
        'public_objective': 'Decouvrir ce qui agite la cave de la taverne.',
        'starting_location': {'name': 'Cave de la taverne'},
      },
    'de' => const {
        'title': 'Die Wyrmtuer',
        'setting': 'Ein Keller unter einer Taverne am Fuss eines alten Huegels.',
        'tone': 'kurzes Abenteuer, Spannung, Cliffhanger',
        'public_objective': 'Herausfinden, was den Keller der Taverne aufwuehlt.',
        'starting_location': {'name': 'Keller der Taverne'},
      },
    'es' => const {
        'title': 'La puerta del wyrm',
        'setting': 'Una bodega bajo una taberna, al pie de una colina antigua.',
        'tone': 'aventura corta, tension, cliffhanger',
        'public_objective': 'Descubrir que agita la bodega de la taberna.',
        'starting_location': {'name': 'Bodega de la taberna'},
      },
    _ => const {
        'title': 'The Wyrm Gate',
        'setting': 'A cellar beneath a tavern, at the foot of an ancient hill.',
        'tone': 'short adventure, tension, cliffhanger',
        'public_objective': 'Find out what stirs in the tavern cellar.',
        'starting_location': {'name': 'Tavern cellar'},
      },
  };
}

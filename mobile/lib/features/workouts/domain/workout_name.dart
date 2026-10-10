/// Nome do treino separado em etiqueta e título.
///
/// O personal digita um nome livre, como "Treino A - Full body". Quando há um separador
/// (" - ", " – " ou " · "), a primeira parte vira a etiqueta ("Treino A") e a segunda o
/// título em destaque ("Full body"). Sem separador, o nome inteiro é o título.
({String? tag, String title}) splitWorkoutName(String name) {
  final parts = name.split(RegExp(r'\s[-–·]\s'));
  if (parts.length >= 2 && parts.first.trim().isNotEmpty) {
    return (tag: parts.first.trim(), title: parts.sublist(1).join(' - ').trim());
  }
  return (tag: null, title: name.trim());
}

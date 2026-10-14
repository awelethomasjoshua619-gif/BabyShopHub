Future<(A, B)> loadInOrder2<A, B>(
  Future<A> Function() first,
  Future<B> Function() second,
) async {
  final a = await first();
  final b = await second();
  return (a, b);
}

Future<(A, B, C)> loadInOrder3<A, B, C>(
  Future<A> Function() first,
  Future<B> Function() second,
  Future<C> Function() third,
) async {
  final a = await first();
  final b = await second();
  final c = await third();
  return (a, b, c);
}

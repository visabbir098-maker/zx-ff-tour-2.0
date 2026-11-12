void _wallet(BuildContext ctx) {
  final uidC = TextEditingController();
  final amtC = TextEditingController();
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      title: const Text("Wallet Control"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: uidC,
            decoration: const InputDecoration(labelText: "User UID"),
          ),
          TextField(
            controller: amtC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Amount"),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            final amt = int.tryParse(amtC.text.trim()) ?? 0;
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uidC.text.trim())
                .update({'balance': FieldValue.increment(amt)});
            Navigator.pop(ctx);
          },
          child: const Text("Update"),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

class DetailPageWidget extends StatefulWidget {
  final int? placeId;

  const DetailPageWidget({super.key, this.placeId});

  @override
  State<DetailPageWidget> createState() => _DetailPageWidgetState();
}

class _DetailPageWidgetState extends State<DetailPageWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Page'),
      ),
      body: Center(
        child: Text('Detail Page Placeholder for Place ID: ${widget.placeId}'),
      ),
    );
  }
}

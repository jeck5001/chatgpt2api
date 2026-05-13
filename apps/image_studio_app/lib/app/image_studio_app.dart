import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class ImageStudioApp extends StatelessWidget {
  const ImageStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Image Studio',
      theme: buildImageStudioTheme(),
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}

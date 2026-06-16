import 'package:flutter/material.dart';

class AvatarBuilder {
  static Widget build({
    required String gender,
    required Map<String, String> outfit,
    required double height,
    double offsetY = -62,
    bool isHijabi = false,
  }) {
    final bool isFemale = gender.toLowerCase().trim() == "female";
    final String basePath = isFemale ? "assets/avatar/girl" : "assets/avatar/boy";

    String headImage = (isHijabi && isFemale) ? "hijab_head.png" : "head.png";
    final bool headOnTop = (isHijabi && isFemale);

    final top = outfit["top"];
    final bottom = outfit["bottom"];
    final shoes = outfit["shoes"];
    
    final beanie = outfit["beanie"];
    final scarf = outfit["scarf"];
    final sunglasses = outfit["sunglasses"];
    final sockItem = outfit["socks"]; 

    final avatarH = height * 0.8;
    double xOffset = (isHijabi && isFemale) ? -4.5 : 0.0;

    // --- Widget Builders ---

    Widget buildSocks() {
      return (sockItem != null && sockItem.isNotEmpty)
          ? Positioned(
              top: avatarH * -0.1, 
              child: Transform.translate(
                offset: Offset(isHijabi ? -1.0 : 2.0, 10.0), 
                child: Image.asset(
                  "$basePath/base/$sockItem.png",
                  height: avatarH * 1.55,
                  fit: BoxFit.contain,
                ),
              ),
            )
          : const SizedBox();
    }
    
    Widget buildHead() => Positioned(
        top: avatarH * 0.00,
        child: Transform.translate(
          offset: Offset(xOffset, 0), 
          child: Image.asset("$basePath/base/$headImage", height: avatarH * 1.55, fit: BoxFit.contain),
        ),
      );

    Widget buildBottom() => bottom != null 
      ? Positioned(
          top: avatarH * 0.01,
          child: Image.asset("$basePath/bottom/$bottom.png", height: avatarH * 1.50, fit: BoxFit.contain),
        )
      : const SizedBox();

    Widget buildTop() => top != null
      ? Positioned(
          top: avatarH * 0.01,
          child: Image.asset("$basePath/tops/$top.png", height: avatarH * 1.50, fit: BoxFit.contain),
        )
      : const SizedBox();

    Widget buildShoes() => shoes != null
      ? Positioned(
          top: avatarH * -0.066,
          child: Image.asset("$basePath/shoes/$shoes.png", height: avatarH * 1.6, fit: BoxFit.contain),
        )
      : const SizedBox();

    Widget buildMask() {
      String maskFile = isHijabi ? "mask_hijabi.png" : "mask.png";
      bool hasMask = outfit.containsValue("mask") || outfit.containsKey("force_mask") || outfit["mask"]?.isNotEmpty == true;
      return hasMask 
        ? Positioned(
            top: avatarH * 0.00,
            child: Transform.translate(
              offset: Offset(xOffset, 0),
              child: Image.asset("$basePath/base/$maskFile", height: avatarH * 1.55, fit: BoxFit.contain),
            ),
          )
        : const SizedBox();
    }

    Widget buildScarf() => scarf != null && scarf.isNotEmpty
      ? Positioned(
          top: avatarH * 0.00,
          child: Transform.translate(
            offset: Offset(xOffset, 0),
            child: Image.asset("$basePath/base/$scarf.png", height: avatarH * 1.55, fit: BoxFit.contain),
          ),
        )
      : const SizedBox();

    Widget buildBeanie() => beanie != null && beanie.isNotEmpty
      ? Positioned(
          top: avatarH * 0.00,
          child: Transform.translate(
            offset: Offset(xOffset, 0),
            child: Image.asset("$basePath/base/$beanie.png", height: avatarH * 1.55, fit: BoxFit.contain),
          ),
        )
      : const SizedBox();

    Widget buildSunglasses() => sunglasses != null && sunglasses.isNotEmpty
      ? Positioned(
          top: avatarH * 0.00,
          child: Transform.translate(
            offset: Offset(xOffset, 0),
            child: Image.asset("$basePath/base/$sunglasses.png", height: avatarH * 1.55, fit: BoxFit.contain),
          ),
        )
      : const SizedBox();

    return Transform.translate(
      offset: Offset(0, offsetY),
      child: SizedBox(
        height: avatarH,
        width: avatarH * 0.55,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            buildSocks(), 
            buildShoes(),

            if (headOnTop) ...[
              // 🧕 HIJABI MODE
              buildBottom(),
              buildTop(),      // Jacket
              buildHead(),     // Hijab head
              buildBeanie(),   // 1. Beanie goes on Head
              buildMask(),     // 2. Mask
              buildScarf(),    // 🧣 3. SCARF MOVED HERE (So it sits ON TOP of Beanie/Hijab)
              buildSunglasses(), 
            ] else ...[
              // 👩 NORMAL MODE
              buildHead(), 
              buildBottom(),
              buildTop(),   
              buildBeanie(),   // 1. Beanie first
              buildScarf(),    // 🧣 2. SCARF MOVED HERE (So it's not hidden by Beanie)
              buildMask(),
              buildSunglasses(), 
            ],
          ],
        ),
      ),
    );
  }
}
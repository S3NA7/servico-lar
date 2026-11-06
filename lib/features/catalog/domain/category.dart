import 'package:flutter/material.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
  });

  final int id;
  final String name;
  final String slug;

  /// Nome do ícone Material salvo no banco.
  final String icon;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        icon: (json['icon'] as String?) ?? 'build',
      );

  IconData get iconData => _icons[icon] ?? fallbackIcon;

  static const fallbackIcon = Icons.build_outlined;

  static const _icons = <String, IconData>{
    'electrical_services': Icons.electrical_services_outlined,
    'plumbing': Icons.plumbing_outlined,
    'cleaning_services': Icons.cleaning_services_outlined,
    'format_paint': Icons.format_paint_outlined,
    'chair': Icons.chair_outlined,
    'handyman': Icons.handyman_outlined,
    'build': Icons.build_outlined,
  };

  @override
  bool operator ==(Object other) => other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

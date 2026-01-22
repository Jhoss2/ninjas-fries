import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const NinjasFriesApp(),
    );
  }
}

// ===================== MODÈLES DE DONNÉES =====================

class MenuItem {
  final int id;
  final String name;
  final int price;
  final String image;
  final String type;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    this.type = 'plat',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image': image,
        'type': type,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'],
        name: json['name'],
        price: json['price'],
        image: json['image'],
        type: json['type'] ?? 'plat',
      );
}

class ExtraItem {
  final int id;
  final String name;
  final int price;
  final String image;

  ExtraItem({
    required this.id,
    required this.name,
    this.price = 0,
    this.image = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image': image,
      };

  factory ExtraItem.fromJson(Map<String, dynamic> json) => ExtraItem(
        id: json['id'],
        name: json['name'],
        price: json['price'] ?? 0,
        image: json['image'] ?? '',
      );
}

class CartItem {
  final MenuItem item;
  final int quantity;
  final List<ExtraItem> sauces;
  final List<ExtraItem> garnitures;
  final int totalPrice;
  final int cartId;

  CartItem({
    required this.item,
    required this.quantity,
    required this.sauces,
    required this.garnitures,
    required this.totalPrice,
    required this.cartId,
  });

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'quantity': quantity,
        'sauces': sauces.map((s) => s.toJson()).toList(),
        'garnitures': garnitures.map((g) => g.toJson()).toList(),
        'totalPrice': totalPrice,
        'cartId': cartId,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        item: MenuItem.fromJson(json['item']),
        quantity: json['quantity'],
        sauces: (json['sauces'] as List)
            .map((s) => ExtraItem.fromJson(s))
            .toList(),
        garnitures: (json['garnitures'] as List)
            .map((g) => ExtraItem.fromJson(g))
            .toList(),
        totalPrice: json['totalPrice'],
        cartId: json['cartId'],
      );
}

class Order {
  final int id;
  final String date;
  final String time;
  final List<CartItem> items;
  final int total;
  final String status;

  Order({
    required this.id,
    required this.date,
    required this.time,
    required this.items,
    required this.total,
    this.status = 'en_attente',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'status': status,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        date: json['date'],
        time: json['time'],
        items:
            (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
        total: json['total'],
        status: json['status'] ?? 'en_attente',
      );
}

// ===================== COULEURS QUOTIDIENNES =====================

const List<Color> DAILY_COLORS = [
  Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFF59E0B), Color(0xFFEAB308),
  Color(0xFF84CC16), Color(0xFF22C55E), Color(0xFF10B981), Color(0xFF14B8A6),
  Color(0xFF06B6D4), Color(0xFF0EA5E9), Color(0xFF3B82F6), Color(0xFF6366F1),
  Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFD946EF), Color(0xFFEC4899),
  Color(0xFFF43F5E), Color(0xFFFB7185), Color(0xFFFB923C), Color(0xFFFBBF24),
  Color(0xFFA3E635), Color(0xFF4ADE80), Color(0xFF34D399), Color(0xFF2DD4BF),
  Color(0xFF22D3EE), Color(0xFF38BDF8), Color(0xFF60A5FA), Color(0xFF818CF8),
  Color(0xFFA78BFA), Color(0xFFC084FC),
];

// ===================== APPLICATION PRINCIPALE =====================

class NinjasFriesApp extends StatefulWidget {
  const NinjasFriesApp({Key? key}) : super(key: key);

  @override
  State<NinjasFriesApp> createState() => _NinjasFriesAppState();
}

class _NinjasFriesAppState extends State<NinjasFriesApp> {
  String view = 'menu';
  int activeIndex = 0;
  int quantity = 1;
  bool showSaucePicker = false;
  bool showGarniturePicker = false;
  bool orderSent = false;
  bool showPassModal = false;
  String passwordInput = '';
  String? activeForm;

  String logoUrl = '';
  String? qrCodeUrl;

  List<MenuItem> menuItems = [];
  List<ExtraItem> sauces = [];
  List<ExtraItem> garnitures = [];

  List<ExtraItem> selectedSauces = [];
  List<ExtraItem> selectedGarnitures = [];

  List<CartItem> cart = [];
  List<Order> orderHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMenu = prefs.getString('menu_items');
    final savedSauces = prefs.getString('sauces');
    final savedGarnitures = prefs.getString('garnitures');
    final savedHistory = prefs.getString('order_history');
    final savedLogo = prefs.getString('logo_url');
    final savedQr = prefs.getString('qr_code_url');

    setState(() {
      if (savedMenu != null) {
        menuItems = (jsonDecode(savedMenu) as List)
            .map((i) => MenuItem.fromJson(i))
            .toList();
      }
      if (savedSauces != null) {
        sauces = (jsonDecode(savedSauces) as List)
            .map((s) => ExtraItem.fromJson(s))
            .toList();
      }
      if (savedGarnitures != null) {
        garnitures = (jsonDecode(savedGarnitures) as List)
            .map((g) => ExtraItem.fromJson(g))
            .toList();
      }
      if (savedHistory != null) {
        orderHistory = (jsonDecode(savedHistory) as List)
            .map((o) => Order.fromJson(o))
            .toList();
      }
      logoUrl = savedLogo ?? '';
      qrCodeUrl = savedQr;
    });
  }

  Future<void> _saveMenuItems() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
        'menu_items', jsonEncode(menuItems.map((i) => i.toJson()).toList()));
  }

  Future<void> _saveSauces() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(
        'sauces', jsonEncode(sauces.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveGarnitures() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('garnitures',
        jsonEncode(garnitures.map((g) => g.toJson()).toList()));
  }

  Future<void> _saveOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('order_history',
        jsonEncode(orderHistory.map((o) => o.toJson()).toList()));
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('logo_url', logoUrl);
    if (qrCodeUrl != null) prefs.setString('qr_code_url', qrCodeUrl!);
  }

  void nextItem() {
    if (menuItems.isEmpty) return;
    setState(() {
      activeIndex = (activeIndex + 1) % menuItems.length;
      quantity = 1;
      resetExtras();
    });
  }

  void prevItem() {
    if (menuItems.isEmpty) return;
    setState(() {
      activeIndex = (activeIndex - 1 + menuItems.length) % menuItems.length;
      quantity = 1;
      resetExtras();
    });
  }

  void updateQuantity(int delta) {
    setState(() {
      quantity = max(1, quantity + delta);
    });
  }

  void resetExtras() {
    setState(() {
      selectedSauces = [];
      selectedGarnitures = [];
      showSaucePicker = false;
      showGarniturePicker = false;
    });
  }

  Future<void> handleImageUpload(Function(String) callback) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      callback('data:image/jpeg;base64,$base64Image');
    }
  }

  void toggleExtra(String type, ExtraItem item) {
    setState(() {
      if (type == 'sauces') {
        if (selectedSauces.any((s) => s.id == item.id)) {
          selectedSauces.removeWhere((s) => s.id == item.id);
        } else {
          selectedSauces.add(item);
        }
      } else {
        if (selectedGarnitures.any((g) => g.id == item.id)) {
          selectedGarnitures.removeWhere((g) => g.id == item.id);
        } else {
          selectedGarnitures.add(item);
        }
      }
    });
  }

  void checkAdminAccess() {
    if (passwordInput == "NINJA'S CORPORATION") {
      setState(() {
        view = 'settings';
        showPassModal = false;
        passwordInput = '';
      });
    }
  }

  int get extrasPrice {
    return selectedGarnitures.fold(0, (sum, g) => sum + g.price);
  }

  int get unitPrice {
    if (menuItems.isEmpty) return 0;
    return menuItems[activeIndex].price + extrasPrice;
  }

  int get totalPrice {
    return unitPrice * quantity;
  }

  Future<void> validateOrder() async {
    final now = DateTime.now();
    final order = Order(
      id: now.millisecondsSinceEpoch,
      date:
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      items: cart,
      total: cart.fold(0, (sum, item) => sum + item.totalPrice),
    );

    setState(() {
      orderHistory.insert(0, order);
      cart = [];
      orderSent = true;
    });

    await _saveOrderHistory();

    // Tentative d'impression BLE
    try {
      await _printOrderViaBLE(order);
    } catch (e) {
      print('Erreur impression: $e');
    }

    Future.delayed(const Duration(seconds: 4), () {
      setState(() {
        orderSent = false;
        view = 'menu';
      });
    });
  }

  Future<void> _printOrderViaBLE(Order order) async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    // Recherche d'imprimante
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Note: Vous devrez implémenter la logique complète de connexion
    // et d'envoi ESC/POS selon votre imprimante spécifique
  }

  Future<void> exportOrdersToCSV() async {
    String csv = 'Date;Heure;Articles;Total\n';
    for (var order in orderHistory) {
      final items =
          order.items.map((i) => '${i.quantity}x ${i.item.name}').join(' | ');
      csv += '${order.date};${order.time};$items;${order.total}\n';
    }

    final directory = await getApplicationDocumentsDirectory();
    final file =
        File('${directory.path}/historique_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)],
        text: 'Historique des commandes');
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = menuItems.isNotEmpty ? menuItems[activeIndex] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 390,
          height: 780,
          decoration: BoxDecoration(
            color: const Color(0xFF09090B),
            borderRadius: BorderRadius.circular(48),
          ),
          child: Stack(
            children: [
              // Bouton d'accès admin
              Positioned(
                top: 30,
                left: 20,
                child: GestureDetector(
                  onTap: () => setState(() => showPassModal = true),
                  child: const Icon(Icons.chevron_right, color: Colors.white),
                ),
              ),

              // Contenu principal
              if (view == 'menu') _buildMenuView(currentItem),

              // Modal checkout
              if (view == 'checkout') _buildCheckoutModal(),

              // Écran de confirmation
              if (orderSent) _buildOrderSentScreen(),

              // Modal mot de passe
              if (showPassModal) _buildPasswordModal(),

              // Panneau admin
              if (view == 'settings') _buildAdminPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuView(MenuItem? currentItem) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: logoUrl.isNotEmpty
                ? Image.memory(
                    base64Decode(logoUrl.split(',')[1]),
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  )
                : Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Center(
                      child: Text(
                        "Ninja's\nFries",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
          ),

          // Prix
          if (currentItem != null)
            RichText(
              text: TextSpan(
                text: '$totalPrice ',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF97316),
                ),
                children: const [
                  TextSpan(
                    text: 'FCFA',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          else
            const Text(
              'PRÊT À CRÉER VOTRE MENU NINJA ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF444444),
                fontWeight: FontWeight.w900,
              ),
            ),

          // Carrousel
          if (menuItems.isNotEmpty) _buildCarousel(),

          // Nom et contrôles quantité
          if (currentItem != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => updateQuantity(-1),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: Text(
                    currentItem.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => updateQuantity(1),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),

          // Sélecteurs sauces/garnitures
          if (currentItem != null)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        showSaucePicker = !showSaucePicker;
                        showGarniturePicker = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF27272A)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'SAUCES (${selectedSauces.length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        showGarniturePicker = !showGarniturePicker;
                        showSaucePicker = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF27272A)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'GARNITURES',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                          Icon(Icons.add, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        color: Color(0xFFF97316),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Bouton commander
          if (currentItem != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  cart.add(CartItem(
                    item: currentItem,
                    quantity: quantity,
                    sauces: selectedSauces,
                    garnitures: selectedGarnitures,
                    totalPrice: totalPrice,
                    cartId: DateTime.now().millisecondsSinceEpoch,
                  ));
                  view = 'checkout';
                  resetExtras();
                  quantity = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    'COMMANDER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Flèche gauche
          Positioned(
            left: -10,
            child: GestureDetector(
              onTap: prevItem,
              child: const Icon(Icons.chevron_left, size: 44, color: Colors.white),
            ),
          ),

          // Flèche droite
          Positioned(
            right: -10,
            child: GestureDetector(
              onTap: nextItem,
              child: const Icon(Icons.chevron_right, size: 44, color: Colors.white),
            ),
          ),

          // Items
          ...menuItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            double scale = 0;
            double opacity = 0;

            if (idx == activeIndex) {
              scale = 1.6;
              opacity = 1;
            } else if (idx == (activeIndex - 1 + menuItems.length) % menuItems.length ||
                idx == (activeIndex + 1) % menuItems.length) {
              scale = 0.4;
              opacity = 0.15;
            }

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: item.image.isNotEmpty
                    ? Image.memory(
                        base64Decode(item.image.split(',')[1]),
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(80),
                        ),
                        child: const Center(
                          child: Text(
                            'VISUEL',
                            style: TextStyle(
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCheckoutModal() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bouton fermer
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => setState(() => view = 'menu'),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),

            const SizedBox(height: 60),

            // Liste du panier
            Expanded(
              child: ListView.builder(
                itemCount: cart.length,
                itemBuilder: (context, index) {
                  final item = cart[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF27272A)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity}x ${item.item.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${item.totalPrice} F',
                          style: const TextStyle(
                            color: Color(0xFFF97316),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Bouton valider
            GestureDetector(
              onTap: validateOrder,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    'VALIDER LA COMMANDE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSentScreen() {
    return Container(
      color: const Color(0xFFF97316).withOpacity(0.9),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 80),
            SizedBox(height: 20),
            Text(
              'COMMANDE ENVOYÉE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'VEUILLEZ RETIRER VOTRE TICKET',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordModal() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 30),
              const SizedBox(height: 20),
              TextField(
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF27272A),
                  hintText: 'Code Corporation',
                  hintStyle: const TextStyle(color: Color(0xFF777777)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => passwordInput = value,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showPassModal = false),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(child: Text('ANNULER')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: checkAdminAccess,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(child: Text('ENTRER')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPanel() {
    return Container(
      color: const Color(0xFF09090B),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RÉGLAGES',
                  style: TextStyle(
                    color: Color(0xFFF97316),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    view = 'menu';
                    activeForm = null;
                  }),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),

          // Contenu
          Expanded(
            child: activeForm == null
                ? _buildAdminMenu()
                : _buildAdminForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildAdminButton('AJOUTER PLAT', () {
            setState(() => activeForm = 'plat');
          }),
          const SizedBox(height: 12),
          _buildAdminButton('AJOUTER SAUCE', () {
            setState(() => activeForm = 'sauce');
          }),
          const SizedBox(height: 12),
          _buildAdminButton('AJOUTER GARNITURE', () {
            setState(() => activeForm = 'garniture');
          }),
          const SizedBox(height: 12),
          _buildAdminButton('LOGOS & QR', () {
            setState(() => activeForm = 'logo');
          }),
          const SizedBox(height: 12),
          _buildAdminButton('HISTORIQUE DES VENTES', () {
            setState(() => activeForm = 'history');
          }),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: exportOrdersToCSV,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'EXPORTER L\'HISTORIQUE (CSV)',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bouton retour
          GestureDetector(
            onTap: () => setState(() => activeForm = null),
            child: Row(
              children: const [
                Icon(Icons.chevron_left, color: Color(0xFF777777), size: 14),
                SizedBox(width: 4),
                Text(
                  'RETOUR',
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _getFormContent(),
          ),
        ],
      ),
    );
  }

  Widget _getFormContent() {
    if (activeForm == 'plat' || activeForm == 'sauce' || activeForm == 'garniture') {
      return _buildItemForm();
    } else if (activeForm == 'logo') {
      return _buildLogoForm();
    } else if (activeForm == 'history') {
      return _buildHistoryView();
    }
    return const SizedBox();
  }

  String _tempItemName = '';
  String _tempItemPrice = '';
  String _tempItemImage = '';

  Widget _buildItemForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOUVEAU ${activeForm!.toUpperCase()}',
          style: const TextStyle(
            color: Color(0xFFF97316),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),

        // Sélecteur d'image
        GestureDetector(
          onTap: () {
            handleImageUpload((imageData) {
              setState(() => _tempItemImage = imageData);
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _tempItemImage.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(_tempItemImage.split(',')[1]),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(Icons.camera_alt, color: Colors.white, size: 24),
          ),
        ),

        const SizedBox(height: 10),

        // Nom
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nom',
            hintStyle: const TextStyle(color: Color(0xFF777777)),
            filled: true,
            fillColor: const Color(0xFF27272A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => _tempItemName = value,
        ),

        const SizedBox(height: 10),

        // Prix (sauf pour sauce)
        if (activeForm != 'sauce')
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Prix (FCFA)',
              hintStyle: const TextStyle(color: Color(0xFF777777)),
              filled: true,
              fillColor: const Color(0xFF27272A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => _tempItemPrice = value,
          ),

        const SizedBox(height: 10),

        // Bouton enregistrer
        GestureDetector(
          onTap: () {
            if (_tempItemName.isEmpty) return;

            final id = DateTime.now().millisecondsSinceEpoch;
            final price = int.tryParse(_tempItemPrice) ?? 0;

            setState(() {
              if (activeForm == 'plat') {
                menuItems.add(MenuItem(
                  id: id,
                  name: _tempItemName,
                  price: price,
                  image: _tempItemImage,
                  type: 'plat',
                ));
                _saveMenuItems();
              } else if (activeForm == 'sauce') {
                sauces.add(ExtraItem(
                  id: id,
                  name: _tempItemName,
                  image: _tempItemImage,
                ));
                _saveSauces();
              } else if (activeForm == 'garniture') {
                garnitures.add(ExtraItem(
                  id: id,
                  name: _tempItemName,
                  price: price,
                  image: _tempItemImage,
                ));
                _saveGarnitures();
              }

              _tempItemName = '';
              _tempItemPrice = '';
              _tempItemImage = '';
              activeForm = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'ENREGISTRER',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOGO PRINCIPAL',
          style: TextStyle(
            color: Color(0xFFF97316),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),

        GestureDetector(
          onTap: () {
            handleImageUpload((imageData) {
              setState(() {
                logoUrl = imageData;
                _saveConfig();
              });
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: logoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(logoUrl.split(',')[1]),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(Icons.camera_alt, color: Colors.white, size: 24),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'IMAGE QR CODE',
          style: TextStyle(
            color: Color(0xFFF97316),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),

        GestureDetector(
          onTap: () {
            handleImageUpload((imageData) {
              setState(() {
                qrCodeUrl = imageData;
                _saveConfig();
              });
            });
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: qrCodeUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(qrCodeUrl!.split(',')[1]),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(Icons.camera_alt, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (orderHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'AUCUNE COMMANDE ENREGISTRÉE',
              style: TextStyle(
                color: Color(0xFF777777),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...orderHistory.map((order) {
            final day = int.tryParse(order.date.split('/')[0]) ?? 0;
            final color = DAILY_COLORS[day % 30];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: color, width: 5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${order.date} - ${order.time}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${order.total} F',
                        style: const TextStyle(
                          color: Color(0xFFF97316),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...order.items.map((item) {
                    final saucesText = item.sauces.isNotEmpty
                        ? 'Sauces: ${item.sauces.map((s) => s.name).join(', ')}'
                        : '';
                    final garnituresText = item.garnitures.isNotEmpty
                        ? 'Garnitures: ${item.garnitures.map((g) => g.name).join(', ')}'
                        : '';
                    final extras = [saucesText, garnituresText]
                        .where((s) => s.isNotEmpty)
                        .join(' | ');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x ${item.item.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                          if (extras.isNotEmpty)
                            Text(
                              extras,
                              style: const TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
}

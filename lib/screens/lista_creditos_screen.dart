import 'package:flutter/material.dart';
import '../models/credito.dart';
import '../services/credito_service.dart';
import 'detalle_credito_screen.dart';

class ListaCreditosScreen extends StatefulWidget {
  const ListaCreditosScreen({super.key});

  @override
  State<ListaCreditosScreen> createState() => _ListaCreditosScreenState();
}

class _ListaCreditosScreenState extends State<ListaCreditosScreen> {
  final _creditoService = CreditoService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Credito> _filterCreditos(List<Credito> creditos) {
    if (_searchQuery.isEmpty) {
      return creditos;
    }

    return creditos.where((credito) {
      final nombreCliente = credito.nombreCliente.toLowerCase();
      final etapaActual = credito.etapaActual.toLowerCase();

      return nombreCliente.contains(_searchQuery) ||
          etapaActual.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Créditos'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSearch,
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente o grupo',
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Credito>>(
        stream: _creditoService.getCreditosStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final creditos = snapshot.data ?? [];
          final filteredCreditos = _filterCreditos(creditos);

          if (creditos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay créditos registrados'),
                ],
              ),
            );
          }

          if (filteredCreditos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No se encontraron resultados para:\n"$_searchQuery"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _filterSearch('');
                    },
                    child: const Text('Limpiar búsqueda'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: filteredCreditos.length,
            itemBuilder: (context, index) {
              final credito = filteredCreditos[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      credito.nombreCliente.isNotEmpty
                          ? credito.nombreCliente[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                  title: Text(
                    credito.nombreCliente,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Etapa: ${credito.etapaActual}'),
                      Text(
                        'Inicio: ${credito.fechaInicio.day}/${credito.fechaInicio.month}/${credito.fechaInicio.year}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetalleCreditoScreen(credito: credito),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/nuevo');
        },
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

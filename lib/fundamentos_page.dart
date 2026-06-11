import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FundamentosPage extends StatefulWidget {
  @override
  State<FundamentosPage> createState() => _FundamentosPageState();
}

class _FundamentosPageState extends State<FundamentosPage> {
  
  final Map<String, String> fundamentosFijos = {
    'FUNDAMENTO VÍCTIMA': 'Lo anterior conforme a lo previsto en los artículos 8, 20 apartado "C" de la Constitución Política de los Estados Unidos Mexicanos, 105, 109, 110, 131, 218 y 219 del Código Nacional de Procedimientos Penales, Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México.',
    
    'FUNDAMENTO IMPUTADO': 'Lo anterior conforme a lo previsto en los artículos 8, 20 apartado "B" de la Constitución Política de los Estados Unidos Mexicanos, 105, 113, 115, 131, 218 y 219 del Código Nacional de Procedimientos Penales, Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México.',
    
    'FUNDAMENTO EN ESTUDIO VÍCTIMA': 'Lo anterior conforme a lo previsto en los artículos 1, 8, 16 y 20 apartado "C" de la Constitución Política de los Estados Unidos Mexicanos; 105, 109, 110, 131 y 218 del Código Nacional de Procedimientos Penales; y 54 de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México',
    
    'FUNDAMENTO EN ESTUDIO IMPUTADO': 'Lo anterior conforme a lo previsto en los artículos 1, 8, 16 y 20 apartado "B" de la Constitución Política de los Estados Unidos Mexicanos; 105, 113, 115, 131 y 218 del Código Nacional de Procedimientos Penales; y 54 de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México',
    
    'FUNDAMENTO GENERAL': 'Lo anterior de conformidad con lo previsto en los artículos 8, 20 de la Constitución Política de los Estados Unidos Mexicanos y 131 del Código Nacional de Procedimientos Penales.',
    
    'FUNDAMENTO COPIAS PAGO VÍCTIMA': 'Lo anterior conforme a lo previsto en los artículos 1, 8, 16 y 20 apartado "C" de la Constitución Política de los Estados Unidos Mexicanos; 71, 105, 109, 110, 131 y 218 del Código Nacional de Procedimientos Penales; Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México; y 248 fracción XVII, incisos b) y c) del Código Fiscal para la Ciudad de México.',
    
    'FUNDAMENTO COPIAS PAGO IMPUTADO': 'Lo anterior conforme a lo previsto en los artículos 1, 8, 16 y 20 apartado "B" de la Constitución Política de los Estados Unidos Mexicanos; 71, 105, 113, 115, 131 y 218 del Código Nacional de Procedimientos Penales; Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México; artículos 183, 185 y demás aplicables de la Ley de Transparencia, acceso a la Información Pública y Rendición de Cuentas de la Ciudad de México así como lo dispuesto en el acuerdo A/010/2002, emitido por el Procurador General de Justicia del Distrito Federal y 248 fracción XVII, incisos b) y c) del Código Fiscal para la Ciudad de México.',
    
    'FUNDAMENTO COPIAS VÍCTIMA': 'Lo anterior conforme a lo previsto en los artículos 8, 20 apartado "C" de la Constitución Política de los Estados Unidos Mexicanos, 109 fracción XXII, 131, y 218 del Código Nacional de Procedimientos Penales, Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México.',
    
    'FUNDAMENTO COPIAS IMPUTADO': 'Lo anterior conforme a lo previsto en los artículos 8, 20 apartado "B" de la Constitución Política de los Estados Unidos Mexicanos, 113 fracción VIII, 131, 218 y 219 del Código Nacional de Procedimientos Penales, Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México, artículos 183, 185 y demás aplicables de la Ley de Transparencia, acceso a la Información Pública y Rendición de Cuentas de la Ciudad de México así como lo dispuesto en el acuerdo A/010/2002, emitido por el Procurador General de Justicia del Distrito Federal.',
    
    'FUNDAMENTO NOTIFICACIONES VÍCTIMA': 'Lo anterior conforme a lo previsto en los artículos 8, 20 apartado "C" de la Constitución Política de los Estados Unidos Mexicanos, 82, 109, 131, del Código Nacional de Procedimientos Penales, Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México.',
    
    'FUNDAMENTO NOTIFICACIONES IMPUTADO': 'Lo anterior conforme a lo previsto en los artículos 8, 20 apartado "C" de la Constitución Política de los Estados Unidos Mexicanos, 82, 113, 131, del Código Nacional de Procedimientos Penales, Acuerdos FGJCDMX/18/2025 y FGJCDMX/26/2025, 12, 40 y 41 del Reglamento de la Ley Orgánica de la Procuraduría General de Justicia del Distrito Federal en relación al Segundo y Sexto Transitorio de la Ley Orgánica de la Fiscalía General de Justicia de la Ciudad de México.',
  };

  Map<String, String> fundamentosCustom = {};

  @override
  void initState() {
    super.initState();
    _cargarCustom();
  }

  _cargarCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    Map<String, String> temp = {};
    for (String key in keys) {
      if (key.startsWith('fundamento_custom_')) {
        temp[key.replaceFirst('fundamento_custom_', '')] = prefs.getString(key) ?? '';
      }
    }
    setState(() {
      fundamentosCustom = temp;
    });
  }

  _agregarCustom() async {
    TextEditingController tituloCtrl = TextEditingController();
    TextEditingController textoCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar Fundamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloCtrl,
              decoration: InputDecoration(labelText: 'Título', hintText: 'FUNDAMENTO NUEVO'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: textoCtrl,
              decoration: InputDecoration(labelText: 'Texto del fundamento'),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (tituloCtrl.text.isNotEmpty && textoCtrl.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('fundamento_custom_${tituloCtrl.text}', textoCtrl.text);
                _cargarCustom();
                Navigator.pop(context);
              }
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  _copiarTexto(String texto, String titulo) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$titulo copiado'), duration: Duration(seconds: 1)),
    );
  }

  _eliminarCustom(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fundamento_custom_$key');
    _cargarCustom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fundamentos'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _agregarCustom,
            tooltip: 'Agregar fundamento',
          )
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('FUNDAMENTOS PREDETERMINADOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...fundamentosFijos.entries.map((e) => Card(
            child: ListTile(
              title: Text(e.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: Icon(Icons.copy),
                onPressed: () => _copiarTexto(e.value, e.key),
              ),
              onTap: () => _copiarTexto(e.value, e.key),
            ),
          )),
          
          if (fundamentosCustom.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.all(8),
              child: Text('FUNDAMENTOS PERSONALIZADOS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...fundamentosCustom.entries.map((e) => Card(
              child: ListTile(
                title: Text(e.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy),
                      onPressed: () => _copiarTexto(e.value, e.key),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarCustom(e.key),
                    ),
                  ],
                ),
                onTap: () => _copiarTexto(e.value, e.key),
              ),
            )),
          ]
        ],
      ),
    );
  }
}

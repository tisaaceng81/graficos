import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppGeradoIsaacX());
}
  
class AppGeradoIsaacX extends StatelessWidget {
  const AppGeradoIsaacX({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App IsaacX',
      debugShowCheckedModeBanner: false,
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({Key? key}) : super(key: key);

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  late final WebViewController _controller;

  final String rawJsonScripts = '''{"logica.iscript": "entrada = input()\\nif '|' in entrada:\\n    acao, valor = entrada.split('|', 1)\\n\\n    # Navega\\u00e7\\u00e3o entre telas\\n    if acao == 'nav_interface':\\n        print('mudar_tela:interface')\\n    elif acao == 'ir_tela':\\n        if valor == 'grafico2d':\\n            print('mudar_tela:grafico2d')\\n        elif valor == 'grafico3d':\\n            print('mudar_tela:grafico3d')\\n        elif valor == 'estatistica':\\n            print('mudar_tela:estatistica')\\n    # ---------- Gera\\u00e7\\u00e3o de gr\\u00e1ficos ----------\\n    elif acao == 'gerar_2d':\\n        import matplotlib\\n        matplotlib.use('Agg')\\n        import matplotlib.pyplot as plt\\n        import numpy as np\\n        import io, base64\\n\\n        # Avalia a express\\u00e3o segura (apenas fun\\u00e7\\u00f5es numpy)\\n        x = np.linspace(-10, 10, 400)\\n        try:\\n            y = eval(valor, {'np':np, 'x':x, '__builtins__':{}})\\n        except Exception as exc:\\n            print(f'erro|{exc}')\\n        else:\\n            plt.figure(figsize=(5,3))\\n            plt.style.use('dark_background')\\n            plt.plot(x, y, color='#00fff0')\\n            plt.grid(True, linestyle='--', alpha=0.2)\\n            buf = io.BytesIO()\\n            plt.savefig(buf, format='png')\\n            img_b64 = base64.b64encode(buf.getvalue()).decode()\\n            print(f'imagem_2d|{img_b64}')\\n            plt.close()\\n    elif acao == 'gerar_3d':\\n        import matplotlib\\n        matplotlib.use('Agg')\\n        import matplotlib.pyplot as plt\\n        from mpl_toolkits.mplot3d import Axes3D\\n        import numpy as np, io, base64\\n\\n        # Avalia a express\\u00e3o em (x, y)\\n        X = np.linspace(-6, 6, 80)\\n        Y = np.linspace(-6, 6, 80)\\n        X, Y = np.meshgrid(X, Y)\\n        try:\\n            Z = eval(valor, {'np':np, 'x':X, 'y':Y, '__builtins__':{}})\\n        except Exception as exc:\\n            print(f'erro|{exc}')\\n        else:\\n            fig = plt.figure(figsize=(5,3))\\n            ax = fig.add_subplot(111, projection='3d')\\n            ax.plot_surface(X, Y, Z, cmap='viridis')\\n            ax.set_axis_off()\\n            buf = io.BytesIO()\\n            plt.savefig(buf, format='png')\\n            img_b64 = base64.b64encode(buf.getvalue()).decode()\\n            print(f'imagem_3d|{img_b64}')\\n            plt.close()\\n    elif acao == 'gerar_estat':\\n        import matplotlib\\n        matplotlib.use('Agg')\\n        import matplotlib.pyplot as plt\\n        import numpy as np, io, base64\\n\\n        # Converte a lista de valores\\n        try:\\n            lista = [float(v.strip()) for v in valor.split(',') if v.strip()!='']\\n        except Exception as exc:\\n            print(f'erro|{exc}')\\n        else:\\n            plt.figure(figsize=(5,3))\\n            plt.style.use('dark_background')\\n            plt.hist(lista, bins=15, color='#ffcc00', edgecolor='#fff')\\n            plt.grid(True, linestyle='--', alpha=0.2)\\n            buf = io.BytesIO()\\n            plt.savefig(buf, format='png')\\n            img_b64 = base64.b64encode(buf.getvalue()).decode()\\n            print(f'imagem_estat|{img_b64}')\\n            plt.close()"}''';
  late final Map<String, dynamic> arquivosLogica;
  String telaAtual = "interface";
  
  final bool isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    arquivosLogica = jsonDecode(rawJsonScripts);
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.endsWith('.html') || request.url.contains('file://')) {
              String nomeArquivo = request.url.split('/').last;
              rootBundle.loadString('assets/' + nomeArquivo).then((htmlConteudo) {
                  _controller.loadHtmlString(htmlConteudo, baseUrl: 'https://app.isaacx.com/');
                  telaAtual = nomeArquivo.replaceAll('.html', '');
              });
              return NavigationDecision.prevent; 
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'IsaacBridge',
        onMessageReceived: (JavaScriptMessage message) async {
          final dadosRecebidos = message.message;
          print("DEBUG_MENSAGEM_RECEBIDA: $dadosRecebidos");

          try {
            final dadosJson = jsonDecode(dadosRecebidos);
            final String acaoSolicitada = dadosJson['acao'] ?? "padrao";
            final String valorDigitado = dadosJson['valor'] ?? "x";
            final String pacoteCompleto = acaoSolicitada + "|" + valorDigitado;

            if (isOfflineMode) {
                print("Rodando Kotlin Nativo Offline...");
                
            } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏳ Processando no Servidor...'),
                    backgroundColor: Colors.blueAccent,
                    duration: Duration(seconds: 2),
                  )
                );
                
                String coordenadaReal = "Localização pendente";
                try {
                  Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                  coordenadaReal = pos.latitude.toString() + ", " + pos.longitude.toString();
                } catch(e) {
                  print("Aviso: GPS não autorizado ou desligado.");
                }

                String scriptAlvo = arquivosLogica.containsKey(telaAtual + ".iscript") ? (telaAtual + ".iscript") : 
                                    (arquivosLogica.containsKey("logica.iscript") ? "logica.iscript" : (arquivosLogica.isNotEmpty ? arquivosLogica.keys.first : ""));

                final url = Uri.parse('https://isaac-studio-engine-94vf.onrender.com/api/v1/compilar');
                final response = await http.post(
                  url,
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "projeto_nome": "AppAPK",
                    "arquivos": arquivosLogica,
                    "executar_ficheiro": scriptAlvo,
                    "input_digitado": pacoteCompleto,
                    "dados_hardware": {"gps": coordenadaReal}
                  }),
                );

                if (response.statusCode == 200) {
                  final dados = jsonDecode(response.body);
                  final linkGrafico = dados['link_grafico'];
                  final String logicaServidor = dados['resultado_terminal'] ?? "";

                      if(logicaServidor.contains("window.desenharRotaNoMapa")) {
                          RegExp exp = RegExp(r'window\.desenharRotaNoMapa\([^)]+\)');
                          var match = exp.firstMatch(logicaServidor);
                          if(match != null) {
                              _controller.runJavaScript(match.group(0)!);
                          }
                      }
                      
                      if (logicaServidor.contains("mudar_tela:")) {
                          RegExp exp = RegExp(r"mudar_tela:([a-zA-Z0-9_-]+)");
                          var match = exp.firstMatch(logicaServidor);
                          if (match != null) {
                              String novaTela = match.group(1)!;
                              telaAtual = novaTela; 
                              print("DEBUG_NAVEGACAO: $novaTela");
                              rootBundle.loadString('assets/' + novaTela + '.html').then((htmlConteudo) {
                                  _controller.loadHtmlString(htmlConteudo, baseUrl: 'https://app.isaacx.com/');

                              }).catchError((e) {
                                  print("ERRO_NAVEGACAO: Arquivo 'assets/$novaTela.html' nao encontrado!");
                              });
                          }
                      }
                      
                      if(logicaServidor.contains("abrir_link:")) {
                          RegExp exp = RegExp(r"abrir_link:(https?://[^\s]+)");
                          var match = exp.firstMatch(logicaServidor);
                          if(match != null) {
                              String urlUniversal = match.group(1)!;
                              launchUrl(Uri.parse(urlUniversal), mode: LaunchMode.externalApplication);
                          }
                      }
                  
                  if (logicaServidor.contains("instalar_pacote:")) {
                       RegExp exp = RegExp(r"instalar_pacote:([a-zA-Z0-9_.-]+)");
                       var match = exp.firstMatch(logicaServidor);
                       if (match != null) {
                            _instalarPacoteRemotamente(match.group(1)!);
                       }
                  }
                                                                             
                  if (linkGrafico != null && linkGrafico != 'Nenhum gráfico gerado') {
                     final timeStamp = DateTime.now().millisecondsSinceEpoch;
                     final urlSemCache = "$linkGrafico?t=$timeStamp";
                     
                     final scriptInjecao = '''
                        var urlImagem = "$urlSemCache";
                        var imgHtml = '<img src="' + urlImagem + '" style="width:100%; height:100%; min-height:200px; object-fit:contain; border-radius:8px;" />';
                        var area = document.getElementById('area_grafico');
                        
                        if(area) {
                          area.innerHTML = imgHtml;
                        } else {
                          var fallback = document.createElement('div');
                          fallback.style.cssText = "background-color: #000000; width: 100%; height: 250px; border-radius: 8px; display: flex; justify-content: center; align-items: center; margin-top: 20px; border: 2px solid red;";
                          fallback.innerHTML = imgHtml;
                          document.body.appendChild(fallback);
                        }
                     ''';
                     _controller.runJavaScript(scriptInjecao);
                     
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📊 Gráfico renderizado!'), backgroundColor: Colors.green),
                      );
                  } 
                  
                } else {
                  throw Exception('HTTP ${response.statusCode}');
                }
            } 

          } catch (e) {
             print("ERRO_GERACAO: $e");
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Erro: $e'), backgroundColor: Colors.red),
              );
              
             if (e.toString().contains("SocketException") || e.toString().contains("ClientException")) {
                 final scriptOffline = '''
                    document.body.innerHTML = "<div style='font-family:sans-serif; text-align:center; padding:50px; background:#1A2235; color:white; height:100vh; display:flex; flex-direction:column; justify-content:center;'><h2>Sem Conexão</h2><p>Você está offline. Algumas functions em nuvem foram pausadas.</p><button onclick='window.location.reload()' style='padding:15px; border-radius:8px; background:#00E676; border:none; font-weight:bold; margin-top:20px;'>TENTAR RECONECTAR</button></div>";
                 ''';
                 _controller.runJavaScript(scriptOffline);
             }
          }
        },
      );
      
    _carregarInterface();
  }

  Future<void> _carregarInterface() async {
  final String htmlContent = await rootBundle.loadString('assets/interface.html');
  await _controller.loadHtmlString(htmlContent, baseUrl: 'https://app.isaacx.com/');
          
    bool servicoHabilitado = await Geolocator.isLocationServiceEnabled();
    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    
    if (servicoHabilitado && (permissao == LocationPermission.always || permissao == LocationPermission.whileInUse)) {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2)
      ).listen((Position pos) {
         _controller.runJavaScript("if(typeof window.atualizarGPSNativo === 'function') { window.atualizarGPSNativo(${pos.latitude}, ${pos.longitude}); }");
      });
    }
  }

  Future<void> _instalarPacoteRemotamente(String pacote) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📦 Baixando dependência automática: $pacote...'), backgroundColor: Colors.blueAccent, duration: const Duration(seconds: 4)));
    try {
      final urlStr = isOfflineMode ? 'http://127.0.0.1:8000/api/v1/pip' : 'https://isaac-studio-engine-94vf.onrender.com/api/v1/pip';
      final response = await http.post(
        Uri.parse(urlStr),
        headers: {"Content-Type": "application/json", "X-API-Key": "admin_master_bypass_token"},
        body: jsonEncode({"pacote": pacote}),
      );
      if (response.statusCode == 200) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $pacote instalado! Tente a ação novamente.'), backgroundColor: Colors.green));
      else throw Exception("Erro no servidor ao baixar o pacote.");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Falha ao instalar $pacote'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

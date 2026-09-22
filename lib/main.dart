import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final String serverUrl = 'http://100.76.249.81:3000';
  late final AudioPlayer _player;

  List<String> _playlist = [];
  int _currentIndex = -1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _fetchSongs();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // Exibe a mensagem de erro na tela (SnackBar)
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Busca a lista de músicas do servidor Node
  Future<void> _fetchSongs() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/songs'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _playlist = data.cast<String>();
          _isLoading = false;
        });
      } else {
        _showError('Erro ao carregar lista: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Erro de conexão: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Reproduz a música selecionada com codificação por segmento
  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final relativePath = _playlist[index];

    // Codifica espaços e caracteres especiais em cada pasta/arquivo
    final encodedPath = relativePath
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');

    final fullUrl = '$serverUrl/stream/$encodedPath';

    print('🔊 Tentando tocar: $fullUrl');

    try {
      await _player.stop();
      await _player.setUrl(fullUrl);
      await _player.play();

      setState(() {
        _currentIndex = index;
      });
    } catch (e) {
      print('❌ Erro no just_audio: $e');
      _showError('Erro ao tocar áudio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Player de Músicas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSongs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlist.isEmpty
          ? const Center(child: Text('Nenhuma música encontrada.'))
          : ListView.builder(
        itemCount: _playlist.length,
        itemBuilder: (context, index) {
          final songPath = _playlist[index];
          final isSelected = _currentIndex == index;
          final fileName = songPath.split('/').last;

          return ListTile(
            leading: Icon(
              isSelected ? Icons.graphic_eq : Icons.music_note,
              color: isSelected ? Colors.greenAccent : Colors.white54,
            ),
            title: Text(
              fileName,
              style: TextStyle(
                color: isSelected ? Colors.greenAccent : Colors.white,
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              songPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () => _playTrack(index),
          );
        },
      ),
      bottomNavigationBar: _currentIndex != -1
          ? Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _playlist[_currentIndex].split('/').last,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _playlist[_currentIndex],
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: _currentIndex > 0
                  ? () => _playTrack(_currentIndex - 1)
                  : null,
            ),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final playing = playerState?.playing ?? false;
                return IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    if (playing) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: _currentIndex < _playlist.length - 1
                  ? () => _playTrack(_currentIndex + 1)
                  : null,
            ),
          ],
        ),
      )
          : null,
    );
  }
}
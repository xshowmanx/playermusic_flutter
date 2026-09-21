import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
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
  // Configuração do servidor
  final String serverUrl = 'http://192.168.101.18:3000';

  // Instância do ExoPlayer via just_audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> _playlist = [];
  int _currentIndex = -1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Busca a lista de músicas no servidor Node.js
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
      _showError('Erro de conexão com o servidor: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Executa o streaming via ExoPlayer
  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final relativePath = _playlist[index];
    final encodedPath = Uri.encodeComponent(relativePath);
    final streamUrl = '$serverUrl/api/stream?path=$encodedPath';

    print('Tentando tocar via ExoPlayer: $streamUrl');

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(streamUrl);
      _audioPlayer.play();

      setState(() {
        _currentIndex = index;
      });
    } catch (e) {
      print('Erro ao dar play no audio: $e');
      _showError('Erro ao tocar áudio: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    setState(() {});
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                    stream: _audioPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final playing = playerState?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: _togglePlayPause,
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
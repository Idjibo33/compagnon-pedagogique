import 'dart:ffi';
import 'dart:io';
import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:ffi/ffi.dart';

typedef _StatvfsC = Int32 Function(Pointer<Utf8> path, Pointer<Uint8> buf);
typedef _StatvfsDart = int Function(Pointer<Utf8> path, Pointer<Uint8> buf);

/// Service abstrait de vérification de l'espace disque disponible
abstract class DiskSpaceChecker {
  /// Retourne l'espace disque libre en octets pour un chemin donné,
  /// ou `null` si la vérification est impossible.
  Future<int?> getFreeDiskSpaceBytes([String? path]);

  /// Vérifie si l'espace disque disponible est supérieur ou égal au seuil requis
  /// (par défaut 1.5 Go selon [AppConstants.minFreeDiskSpaceBytes]).
  Future<bool> hasEnoughSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
    String? path,
  });
}

/// Implémentation POSIX basée sur `statvfs` via FFI pour Android et Linux.
class SystemDiskSpaceChecker implements DiskSpaceChecker {
  const SystemDiskSpaceChecker();

  @override
  Future<int?> getFreeDiskSpaceBytes([String? path]) async {
    final rawPath = path ?? Directory.current.path;

    // Si le chemin cible n'existe pas encore, remonter vers le premier ancêtre existant
    String targetPath = rawPath;
    while (
        !Directory(targetPath).existsSync() && !File(targetPath).existsSync()) {
      final parent = Directory(targetPath).parent.path;
      if (parent == targetPath) break;
      targetPath = parent;
    }

    // 1. Essai direct via statvfs (Android et Linux)
    if (Platform.isAndroid || Platform.isLinux) {
      try {
        final dylib = Platform.isAndroid
            ? DynamicLibrary.open('libc.so')
            : DynamicLibrary.process();

        final statvfsFunc =
            dylib.lookupFunction<_StatvfsC, _StatvfsDart>('statvfs');

        final pathPtr = targetPath.toNativeUtf8();
        // Allouer 256 octets pour être certain de couvrir struct statvfs
        final buf = calloc<Uint8>(256);

        try {
          final res = statvfsFunc(pathPtr, buf);
          if (res == 0) {
            final is64Bit = sizeOf<IntPtr>() == 8;
            final int bsize;
            final int frsize;
            final int bavail;

            if (is64Bit) {
              final u64Buf = buf.cast<Uint64>();
              bsize = u64Buf[0];
              frsize = u64Buf[1];
              bavail = u64Buf[4];
            } else {
              final u32Buf = buf.cast<Uint32>();
              bsize = u32Buf[0];
              frsize = u32Buf[1];
              bavail = u32Buf[4];
            }

            final blockSize = frsize > 0 ? frsize : bsize;
            if (blockSize > 0 && bavail >= 0) {
              return bavail * blockSize;
            }
          }
        } finally {
          calloc.free(pathPtr);
          calloc.free(buf);
        }
      } catch (_) {
        // En cas d'erreur FFI, passer au fallback
      }
    }

    // 2. Fallback via la commande df sur Linux / macOS si disponible
    try {
      final result = await Process.run('df', ['-k', targetPath]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            // La 4e colonne correspond généralement aux Ko disponibles
            final availKb = int.tryParse(parts[3]);
            if (availKb != null) {
              return availKb * 1024;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<bool> hasEnoughSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
    String? path,
  }) async {
    final freeBytes = await getFreeDiskSpaceBytes(path);
    // Si on ne peut pas déterminer l'espace (ex. émulateur restreint sans droits),
    // on autorise pour ne pas bloquer un utilisateur légitime,
    // mais si la valeur est connue, on applique le seuil strict.
    if (freeBytes == null) {
      return true;
    }
    return freeBytes >= requiredBytes;
  }

  /// Formate des octets en chaîne lisible (Go ou Mo)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 Mo';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1000) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(2)} Go';
    }
    return '${mb.toStringAsFixed(0)} Mo';
  }
}

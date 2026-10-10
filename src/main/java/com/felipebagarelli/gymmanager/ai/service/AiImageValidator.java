package com.felipebagarelli.gymmanager.ai.service;

import com.felipebagarelli.gymmanager.ai.provider.AiImage;
import com.felipebagarelli.gymmanager.exception.InvalidImageException;

import java.nio.charset.StandardCharsets;

/**
 * Valida a foto pelo conteudo (assinatura dos primeiros bytes), nunca so pelo tipo declarado:
 * aceita JPEG, PNG e WebP ate 10 MB. HEIC e outros formatos sao recusados com mensagem clara
 * (o app converte para JPEG antes de enviar).
 */
public final class AiImageValidator {

    public static final int MAX_BYTES = 10 * 1024 * 1024;
    static final String UNSUPPORTED = "Formato de imagem não suportado. Envie uma foto JPG, PNG ou WebP.";

    private AiImageValidator() {
    }

    public static AiImage validate(byte[] data) {
        if (data == null || data.length == 0) {
            throw new InvalidImageException("A foto está vazia.");
        }
        if (data.length > MAX_BYTES) {
            throw new InvalidImageException("A foto é grande demais (máximo de 10 MB).");
        }
        return new AiImage(mediaTypeOf(data), data);
    }

    private static String mediaTypeOf(byte[] d) {
        if (d.length >= 3 && (d[0] & 0xFF) == 0xFF && (d[1] & 0xFF) == 0xD8 && (d[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (d.length >= 8 && (d[0] & 0xFF) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G'
                && d[4] == 0x0D && d[5] == 0x0A && d[6] == 0x1A && d[7] == 0x0A) {
            return "image/png";
        }
        if (d.length >= 12 && ascii(d, 0, 4).equals("RIFF") && ascii(d, 8, 4).equals("WEBP")) {
            return "image/webp";
        }
        throw new InvalidImageException(UNSUPPORTED);
    }

    private static String ascii(byte[] d, int from, int length) {
        return new String(d, from, length, StandardCharsets.US_ASCII);
    }
}

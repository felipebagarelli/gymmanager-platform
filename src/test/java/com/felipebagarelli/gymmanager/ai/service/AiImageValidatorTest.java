package com.felipebagarelli.gymmanager.ai.service;

import com.felipebagarelli.gymmanager.ai.provider.AiImage;
import com.felipebagarelli.gymmanager.exception.InvalidImageException;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AiImageValidatorTest {

    private static byte[] jpeg() {
        return new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 16, 'J', 'F', 'I', 'F'};
    }

    private static byte[] png() {
        return new byte[]{(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13};
    }

    private static byte[] webp() {
        return "RIFF\u0000\u0000\u0000\u0000WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1);
    }

    @Test
    void acceptsJpegPngAndWebpByContent() {
        AiImage jpg = AiImageValidator.validate(jpeg());
        assertThat(jpg.mediaType()).isEqualTo("image/jpeg");
        assertThat(jpg.data()).isEqualTo(jpeg());
        assertThat(AiImageValidator.validate(png()).mediaType()).isEqualTo("image/png");
        assertThat(AiImageValidator.validate(webp()).mediaType()).isEqualTo("image/webp");
    }

    @Test
    void rejectsHeic_withAClearMessage() {
        byte[] heic = "\u0000\u0000\u0000\u0018ftypheic\u0000\u0000\u0000\u0000".getBytes(StandardCharsets.ISO_8859_1);

        assertThatThrownBy(() -> AiImageValidator.validate(heic))
                .isInstanceOf(InvalidImageException.class)
                .hasMessageContaining("JPG, PNG ou WebP");
    }

    @Test
    void rejectsAnythingThatIsNotAnImage_evenIfNamedLikeOne() {
        byte[] script = "#!/bin/sh\nrm -rf /".getBytes(StandardCharsets.UTF_8);
        byte[] pdf = "%PDF-1.7".getBytes(StandardCharsets.UTF_8);

        assertThatThrownBy(() -> AiImageValidator.validate(script)).isInstanceOf(InvalidImageException.class);
        assertThatThrownBy(() -> AiImageValidator.validate(pdf)).isInstanceOf(InvalidImageException.class);
    }

    @Test
    void rejectsEmptyAndNull() {
        assertThatThrownBy(() -> AiImageValidator.validate(new byte[0])).isInstanceOf(InvalidImageException.class);
        assertThatThrownBy(() -> AiImageValidator.validate(null)).isInstanceOf(InvalidImageException.class);
    }

    @Test
    void rejectsOverTenMegabytes_butAcceptsExactlyTen() {
        byte[] exactly = new byte[AiImageValidator.MAX_BYTES];
        System.arraycopy(jpeg(), 0, exactly, 0, jpeg().length);
        byte[] over = new byte[AiImageValidator.MAX_BYTES + 1];
        System.arraycopy(jpeg(), 0, over, 0, jpeg().length);

        assertThat(AiImageValidator.validate(exactly).mediaType()).isEqualTo("image/jpeg");
        assertThatThrownBy(() -> AiImageValidator.validate(over))
                .isInstanceOf(InvalidImageException.class)
                .hasMessageContaining("10 MB");
    }
}

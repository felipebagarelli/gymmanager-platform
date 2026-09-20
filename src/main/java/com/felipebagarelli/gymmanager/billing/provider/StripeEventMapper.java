package com.felipebagarelli.gymmanager.billing.provider;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * Traduz o JSON de um evento da Stripe (ja com assinatura validada) para {@link BillingNotification}.
 * Le o JSON cru para nao depender de versao de API do SDK.
 */
final class StripeEventMapper {

    private static final JsonMapper MAPPER = JsonMapper.builder().build();

    private StripeEventMapper() {
    }

    static BillingNotification map(String payload) {
        JsonNode root = MAPPER.readTree(payload);
        String eventId = text(root, "id");
        String type = text(root, "type");
        JsonNode object = root.path("data").path("object");

        return switch (type == null ? "" : type) {
            case "checkout.session.completed" -> new BillingNotification(eventId,
                    BillingNotification.Type.CHECKOUT_COMPLETED, localId(object), text(object, "subscription"),
                    null, null, false);
            case "invoice.paid" -> new BillingNotification(eventId, BillingNotification.Type.PAYMENT_SUCCEEDED,
                    null, invoiceSubscription(object), periodEnd(object), null, false);
            case "invoice.payment_failed" -> new BillingNotification(eventId, BillingNotification.Type.PAYMENT_FAILED,
                    null, invoiceSubscription(object), null, null, false);
            case "customer.subscription.deleted" -> new BillingNotification(eventId,
                    BillingNotification.Type.SUBSCRIPTION_CANCELED, null, text(object, "id"), null, null, false);
            case "account.updated" -> new BillingNotification(eventId, BillingNotification.Type.ACCOUNT_UPDATED,
                    null, null, null, text(object, "id"), object.path("charges_enabled").asBoolean(false));
            default -> new BillingNotification(eventId, BillingNotification.Type.IGNORED,
                    null, null, null, null, false);
        };
    }

    private static Long localId(JsonNode object) {
        String value = text(object.path("metadata"), "subscriptionId");
        try {
            return value == null ? null : Long.valueOf(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** A referencia da assinatura na fatura mudou de lugar entre versoes da API: aceita os dois. */
    private static String invoiceSubscription(JsonNode invoice) {
        String direct = text(invoice, "subscription");
        return direct != null ? direct : text(invoice.path("parent").path("subscription_details"), "subscription");
    }

    private static LocalDateTime periodEnd(JsonNode invoice) {
        JsonNode end = invoice.path("lines").path("data").path(0).path("period").path("end");
        if (!end.isNumber()) return null;
        return LocalDateTime.ofInstant(Instant.ofEpochSecond(end.asLong()), ZoneId.systemDefault());
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node.path(field);
        return value.isString() ? value.asString() : null;
    }
}

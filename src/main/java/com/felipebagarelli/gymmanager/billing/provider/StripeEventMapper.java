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

    /** Eventos da conta da plataforma (plano GymManager Pro). */
    static PlatformBillingNotification mapPlatform(String payload) {
        JsonNode root = MAPPER.readTree(payload);
        String eventId = text(root, "id");
        String type = text(root, "type");
        JsonNode object = root.path("data").path("object");

        return switch (type == null ? "" : type) {
            case "checkout.session.completed" -> new PlatformBillingNotification(eventId,
                    PlatformBillingNotification.Type.CHECKOUT_COMPLETED, platformLocalId(object), text(object, "subscription"),
                    null, null, null, null);
            case "customer.subscription.created", "customer.subscription.updated" -> new PlatformBillingNotification(eventId,
                    PlatformBillingNotification.Type.SUBSCRIPTION_UPDATED, platformLocalId(object), text(object, "id"),
                    normalizeStatus(text(object, "status")), subscriptionPeriodEnd(object), epoch(object.path("trial_end")),
                    object.path("cancel_at_period_end").isBoolean() ? object.path("cancel_at_period_end").asBoolean() : null);
            case "invoice.paid" -> new PlatformBillingNotification(eventId, PlatformBillingNotification.Type.PAYMENT_SUCCEEDED,
                    null, invoiceSubscription(object), null, periodEnd(object), null, null);
            case "invoice.payment_failed" -> new PlatformBillingNotification(eventId,
                    PlatformBillingNotification.Type.PAYMENT_FAILED, null, invoiceSubscription(object), null, null, null, null);
            case "customer.subscription.deleted" -> new PlatformBillingNotification(eventId,
                    PlatformBillingNotification.Type.SUBSCRIPTION_CANCELED, platformLocalId(object), text(object, "id"),
                    "canceled", null, null, null);
            default -> new PlatformBillingNotification(eventId, PlatformBillingNotification.Type.IGNORED,
                    null, null, null, null, null, null);
        };
    }

    private static Long platformLocalId(JsonNode object) {
        String value = text(object.path("metadata"), "platformSubscriptionId");
        try {
            return value == null ? null : Long.valueOf(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Status da Stripe reduzido ao que o sistema usa. */
    static String normalizeStatus(String stripeStatus) {
        if (stripeStatus == null) return null;
        return switch (stripeStatus) {
            case "trialing" -> "trialing";
            case "active" -> "active";
            case "past_due", "unpaid" -> "past_due";
            case "canceled", "incomplete_expired" -> "canceled";
            default -> "pending";
        };
    }

    /** O fim do periodo saiu da assinatura para os itens em versoes novas da API: aceita os dois. */
    private static LocalDateTime subscriptionPeriodEnd(JsonNode subscription) {
        LocalDateTime direct = epoch(subscription.path("current_period_end"));
        return direct != null ? direct : epoch(subscription.path("items").path("data").path(0).path("current_period_end"));
    }

    private static LocalDateTime epoch(JsonNode node) {
        if (!node.isNumber()) return null;
        return LocalDateTime.ofInstant(Instant.ofEpochSecond(node.asLong()), ZoneId.systemDefault());
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

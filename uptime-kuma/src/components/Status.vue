<template>
    <span class="badge" :class="'bg-' + color">{{ text }}</span>
</template>

<script>
export default {
    props: {
        /** Current status of monitor */
        status: {
            type: Number,
            default: 0,
        },
    },

    computed: {
        color() {
            if (this.status === 0) {
                return "danger";
            }

            if (this.status === 1) {
                return "primary";
            }

            if (this.status === 2) {
                return "warning";
            }

            if (this.status === 3) {
                return "maintenance";
            }

            return "secondary";
        },

        text() {
            if (this.status === 0) {
                return this.$t("Down");
            }

            if (this.status === 1) {
                return this.$t("Up");
            }

            if (this.status === 2) {
                return this.$t("Pending");
            }

            if (this.status === 3) {
                return this.$t("statusMaintenance");
            }

            return this.$t("Unknown");
        },
    },
};
</script>

<style lang="scss" scoped>
@import "../assets/vars";

span {
    min-width: 64px;
    border-radius: 4px;
    font-family: "DM Sans", sans-serif;
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.02em;
    padding: 0.3em 0.7em;
}
</style>

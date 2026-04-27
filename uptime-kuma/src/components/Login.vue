<template>
    <div class="form-container">
        <div class="form">
            <form @submit.prevent="submit">
                <h1 class="h3 mb-3 fw-normal" />

                <div v-if="!tokenRequired" class="form-floating">
                    <input
                        id="floatingInput"
                        v-model="username"
                        type="text"
                        class="form-control"
                        placeholder="Username"
                        autocomplete="username"
                        required
                    />
                    <label for="floatingInput">{{ $t("Username") }}</label>
                </div>

                <div v-if="!tokenRequired" class="form-floating mt-3">
                    <input
                        id="floatingPassword"
                        v-model="password"
                        type="password"
                        class="form-control"
                        placeholder="Password"
                        autocomplete="current-password"
                        required
                    />
                    <label for="floatingPassword">{{ $t("Password") }}</label>
                </div>

                <div v-if="tokenRequired">
                    <div class="form-floating mt-3">
                        <input
                            id="otp"
                            ref="otpInput"
                            v-model="token"
                            type="text"
                            maxlength="6"
                            class="form-control"
                            placeholder="123456"
                            autocomplete="one-time-code"
                            required
                        />
                        <label for="otp">{{ $t("Token") }}</label>
                    </div>
                </div>

                <div class="form-check mb-3 mt-3 d-flex justify-content-center pe-4">
                    <div class="form-check">
                        <input
                            id="remember"
                            v-model="$root.remember"
                            type="checkbox"
                            value="remember-me"
                            class="form-check-input"
                        />

                        <label class="form-check-label" for="remember">
                            {{ $t("Remember me") }}
                        </label>
                    </div>
                </div>
                <button class="w-100 btn btn-primary" type="submit" :disabled="processing">
                    {{ $t("Login") }}
                </button>

                <div v-if="res && !res.ok" class="alert alert-danger mt-3" role="alert">
                    {{ $t(res.msg) }}
                </div>
            </form>
        </div>
    </div>
</template>

<script>
export default {
    data() {
        return {
            processing: false,
            username: "",
            password: "",
            token: "",
            res: null,
            tokenRequired: false,
        };
    },

    watch: {
        tokenRequired(newVal) {
            if (newVal) {
                this.$nextTick(() => {
                    this.$refs.otpInput?.focus();
                });
            }
        },
    },

    mounted() {
        document.title += " - Login";
    },

    unmounted() {
        document.title = document.title.replace(" - Login", "");
    },

    methods: {
        /**
         * Submit the user details and attempt to log in
         * @returns {void}
         */
        submit() {
            this.processing = true;

            this.$root.login(this.username, this.password, this.token, (res) => {
                this.processing = false;

                if (res.tokenRequired) {
                    this.tokenRequired = true;
                } else {
                    this.res = res;
                }
            });
        },
    },
};
</script>

<style lang="scss" scoped>
@import "../assets/vars";

.form-container {
    display: flex;
    align-items: center;
    padding-top: 60px;
    padding-bottom: 40px;
}

.form-floating {
    > label {
        padding-left: 1rem;
        font-size: 14px;
        color: $secondary-text;
    }

    > .form-control {
        padding-left: 1rem;
        border-radius: 6px;
        border: 1px solid rgba(0, 0, 0, 0.12);
        font-size: 15px;

        &:focus {
            border-color: $primary;
            box-shadow: 0 0 0 2px rgba($primary, 0.12);
        }

        .dark & {
            background-color: $dark-bg2;
            color: $dark-font-color;
            border-color: $dark-border-color;

            &:focus {
                border-color: $primary;
                box-shadow: 0 0 0 2px rgba($primary, 0.2);
            }
        }
    }
}

.form {
    width: 100%;
    max-width: 360px;
    padding: 2rem;
    margin: auto;
    text-align: center;
    background-color: $card-bg;
    border-radius: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06), 0 1px 2px rgba(0, 0, 0, 0.04);

    .dark & {
        background-color: $dark-bg;
        box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
    }
}

.btn-primary {
    border-radius: 6px;
    font-weight: 600;
    font-size: 15px;
    padding: 0.6rem 1.5rem;
}

.alert-danger {
    border-radius: 6px;
    font-size: 14px;
}

.form-check-label {
    font-size: 14px;
    color: $secondary-text;
}
</style>

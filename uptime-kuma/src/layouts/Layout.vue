<template>
    <div :class="classes">
        <div v-if="!$root.socket.connected && !$root.socket.firstConnect" class="lost-connection">
            <div class="container-fluid">
                {{ $root.connectionErrorMsg }}
                <div v-if="$root.showReverseProxyGuide">
                    {{ $t("Using a Reverse Proxy?") }}
                    <a href="https://github.com/louislam/uptime-kuma/wiki/Reverse-Proxy" target="_blank">
                        {{ $t("Check how to config it for WebSocket") }}
                    </a>
                </div>
            </div>
        </div>

        <!-- Desktop header -->
        <header v-if="!$root.isMobile" class="d-flex flex-wrap justify-content-center py-3 mb-3 border-bottom">
            <router-link
                to="/dashboard"
                class="d-flex align-items-center mb-3 mb-md-0 me-md-auto text-dark text-decoration-none"
            >
                <object class="bi me-2 ms-4" width="40" height="40" data="/icon.svg" />
                <span class="fs-4 title">{{ $t("Uptime Kuma") }}</span>
            </router-link>

            <a
                v-if="hasNewVersion"
                target="_blank"
                href="https://github.com/louislam/uptime-kuma/releases"
                class="btn btn-primary me-3"
            >
                <font-awesome-icon icon="arrow-alt-circle-up" />
                {{ $t("New Update") }}
            </a>

            <ul class="nav nav-pills">
                <li v-if="$root.loggedIn" class="nav-item me-2">
                    <router-link to="/manage-status-page" class="nav-link">
                        <font-awesome-icon icon="stream" />
                        {{ $t("Status Pages") }}
                    </router-link>
                </li>
                <li v-if="$root.loggedIn" class="nav-item me-2">
                    <router-link to="/dashboard" class="nav-link">
                        <font-awesome-icon icon="tachometer-alt" />
                        {{ $t("Dashboard") }}
                    </router-link>
                </li>
                <li v-if="$root.loggedIn" class="nav-item">
                    <div class="dropdown dropdown-profile-pic">
                        <div class="nav-link" data-bs-toggle="dropdown">
                            <div class="profile-pic">{{ $root.usernameFirstChar }}</div>
                            <font-awesome-icon icon="angle-down" />
                        </div>

                        <!-- Header's Dropdown Menu -->
                        <ul class="dropdown-menu">
                            <!-- Username -->
                            <li>
                                <i18n-t
                                    v-if="$root.username != null"
                                    tag="span"
                                    keypath="signedInDisp"
                                    class="dropdown-item-text"
                                >
                                    <strong>{{ $root.username }}</strong>
                                </i18n-t>
                                <span v-if="$root.username == null" class="dropdown-item-text">
                                    {{ $t("signedInDispDisabled") }}
                                </span>
                            </li>

                            <li><hr class="dropdown-divider" /></li>

                            <!-- Functions -->
                            <li>
                                <router-link
                                    to="/maintenance"
                                    class="dropdown-item"
                                    :class="{ active: $route.path.includes('manage-maintenance') }"
                                >
                                    <font-awesome-icon icon="wrench" />
                                    {{ $t("Maintenance") }}
                                </router-link>
                            </li>

                            <li>
                                <router-link
                                    to="/settings/general"
                                    class="dropdown-item"
                                    :class="{ active: $route.path.includes('settings') }"
                                >
                                    <font-awesome-icon icon="cog" />
                                    {{ $t("Settings") }}
                                </router-link>
                            </li>

                            <li>
                                <a
                                    href="https://github.com/louislam/uptime-kuma/wiki"
                                    class="dropdown-item"
                                    target="_blank"
                                >
                                    <font-awesome-icon icon="info-circle" />
                                    {{ $t("Help") }}
                                </a>
                            </li>

                            <li v-if="$root.loggedIn && $root.socket.token !== 'autoLogin'">
                                <button class="dropdown-item" @click="$root.logout">
                                    <font-awesome-icon icon="sign-out-alt" />
                                    {{ $t("Logout") }}
                                </button>
                            </li>
                        </ul>
                    </div>
                </li>
            </ul>
        </header>

        <!-- Mobile header -->
        <header v-else class="d-flex flex-wrap justify-content-center pt-2 pb-2 mb-3">
            <router-link to="/dashboard" class="d-flex align-items-center text-dark text-decoration-none">
                <object class="bi" width="40" height="40" data="/icon.svg" />
                <span class="fs-4 title ms-2">Uptime Kuma</span>
            </router-link>
        </header>

        <main>
            <router-view v-if="$root.loggedIn" />
            <Login v-if="!$root.loggedIn && $root.allowLoginDialog" />
        </main>

        <!-- Mobile Only -->
        <div v-if="$root.isMobile" style="width: 100%; height: calc(60px + env(safe-area-inset-bottom))" />
        <nav v-if="$root.isMobile && $root.loggedIn" class="bottom-nav">
            <router-link to="/dashboard" class="nav-link">
                <div><font-awesome-icon icon="tachometer-alt" /></div>
                {{ $t("Home") }}
            </router-link>

            <router-link to="/list" class="nav-link">
                <div><font-awesome-icon icon="list" /></div>
                {{ $t("List") }}
            </router-link>

            <router-link to="/add" class="nav-link">
                <div><font-awesome-icon icon="plus" /></div>
                {{ $t("Add") }}
            </router-link>

            <router-link to="/settings" class="nav-link">
                <div><font-awesome-icon icon="cog" /></div>
                {{ $t("Settings") }}
            </router-link>
        </nav>

        <button
            v-if="numActiveToasts != 0"
            type="button"
            class="btn btn-normal clear-all-toast-btn"
            @click="clearToasts"
        >
            <font-awesome-icon icon="times" />
        </button>
    </div>
</template>

<script>
import Login from "../components/Login.vue";
import compareVersions from "compare-versions";
import { useToast } from "vue-toastification";
const toast = useToast();

export default {
    components: {
        Login,
    },

    data() {
        return {
            toastContainer: null,
            numActiveToasts: 0,
            toastContainerObserver: null,
        };
    },

    computed: {
        // Theme or Mobile
        classes() {
            const classes = {};
            classes[this.$root.theme] = true;
            classes["mobile"] = this.$root.isMobile;
            return classes;
        },

        hasNewVersion() {
            if (this.$root.info.latestVersion && this.$root.info.version) {
                return compareVersions(this.$root.info.latestVersion, this.$root.info.version) >= 1;
            } else {
                return false;
            }
        },
    },

    watch: {},

    mounted() {
        this.toastContainer = document.querySelector(".bottom-right.toast-container");

        // Watch the number of active toasts
        this.toastContainerObserver = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
                if (mutation.type === "childList") {
                    this.numActiveToasts = mutation.target.children.length;
                }
            }
        });

        if (this.toastContainer != null) {
            this.toastContainerObserver.observe(this.toastContainer, { childList: true });
        }
    },

    beforeUnmount() {
        this.toastContainerObserver.disconnect();
    },

    methods: {
        /**
         * Clear all toast notifications.
         * @returns {void}
         */
        clearToasts() {
            toast.clear();
        },
    },
};
</script>

<style lang="scss" scoped>
@import "../assets/vars.scss";

.nav-link {
    transition: background-color 0.2s ease, color 0.2s ease;

    &:hover {
        background-color: $highlight-white;
        color: $primary;

        .dark & {
            background-color: $dark-bg2;
            color: $dark-font-color;
        }
    }

    &.status-page {
        background-color: rgba(0, 0, 0, 0.04);
    }
}

.bottom-nav {
    z-index: 1000;
    position: fixed;
    bottom: 0;
    height: calc(60px + env(safe-area-inset-bottom));
    width: 100%;
    left: 0;
    background-color: $card-bg;
    border-top: 1px solid rgba(0, 0, 0, 0.06);
    box-shadow: 0 -1px 4px rgba(0, 0, 0, 0.04);
    text-align: center;
    white-space: nowrap;
    padding: 0 10px env(safe-area-inset-bottom);

    a {
        text-align: center;
        width: 25%;
        display: inline-block;
        height: 100%;
        padding: 8px 10px 0;
        font-size: 12px;
        font-weight: 500;
        color: $secondary-text;
        overflow: hidden;
        text-decoration: none;
        transition: color 0.15s ease;

        &.router-link-exact-active,
        &.active {
            color: $primary;
            font-weight: 600;
        }

        div {
            font-size: 20px;
        }
    }
}

main {
    min-height: calc(100vh - 160px);
}

.title {
    font-family: "Libre Baskerville", Georgia, serif;
    font-weight: 400;
    letter-spacing: -0.01em;
}

.nav {
    margin-right: 25px;
}

.lost-connection {
    padding: 8px 12px;
    background-color: $danger;
    color: white;
    position: fixed;
    width: 100%;
    z-index: 99999;
    font-size: 14px;
}

.dropdown-profile-pic {
    user-select: none;

    .nav-link {
        cursor: pointer;
        display: flex;
        gap: 6px;
        align-items: center;
        background-color: rgba(0, 0, 0, 0.04);
        padding: 0.5rem 0.8rem;
        transition: background-color 0.15s ease;

        &:hover {
            background-color: rgba(0, 0, 0, 0.08);
        }
    }

    .dropdown-menu {
        transition: opacity 0.15s ease;
        padding-left: 0;
        padding-bottom: 0;
        margin-top: 8px !important;
        border-radius: 8px;
        border: 1px solid rgba(0, 0, 0, 0.08);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
        overflow: hidden;

        .dropdown-divider {
            margin: 0;
            border-top: 1px solid rgba(0, 0, 0, 0.06);
            background-color: transparent;
        }

        .dropdown-item-text {
            font-size: 13px;
            padding-bottom: 0.7rem;
            color: $secondary-text;
        }

        .dropdown-item {
            padding: 0.6rem 1rem;
            font-size: 14px;
            transition: background-color 0.1s ease;
        }

        .dark & {
            background-color: $dark-bg;
            color: $dark-font-color;
            border-color: $dark-border-color;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);

            .dropdown-item {
                color: $dark-font-color;

                &.active {
                    color: white;
                    background-color: $primary !important;
                }

                &:hover {
                    background-color: $dark-bg2;
                }
            }
        }
    }

    .profile-pic {
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        background-color: $primary;
        width: 24px;
        height: 24px;
        margin-right: 5px;
        border-radius: 6px;
        font-weight: 600;
        font-size: 10px;
    }
}

.dark {
    header {
        background-color: $dark-header-bg;
        border-bottom-color: $dark-border-color !important;

        span {
            color: $dark-font-color;
        }
    }

    .bottom-nav {
        background-color: $dark-bg;
        border-top-color: $dark-border-color;
    }
}

.clear-all-toast-btn {
    position: fixed;
    right: 1em;
    bottom: 1em;
    font-size: 1.2em;
    padding: 9px 15px;
    width: 48px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    z-index: 100;

    .dark & {
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
    }
}

@media (max-width: 770px) {
    .clear-all-toast-btn {
        bottom: 72px;
    }
}
</style>

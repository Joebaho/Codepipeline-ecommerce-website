locals {
  service_definitions = {
    adservice = {
      port              = 9555
      cpu               = 512
      memory            = 1024
      desired_count     = var.default_service_desired_count
      build_context     = "src/adservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT = "9555"
      }
    }
    cartservice = {
      port              = 7070
      cpu               = 512
      memory            = 1024
      desired_count     = var.default_service_desired_count
      build_context     = "src/cartservice/src"
      service_discovery = true
      load_balanced     = false
      environment = {
        REDIS_ADDR = "redis-cart.${var.service_discovery_namespace}:6379"
      }
    }
    checkoutservice = {
      port              = 5050
      cpu               = 512
      memory            = 1024
      desired_count     = var.default_service_desired_count
      build_context     = "src/checkoutservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT                         = "5050"
        PRODUCT_CATALOG_SERVICE_ADDR = "productcatalogservice.${var.service_discovery_namespace}:3550"
        SHIPPING_SERVICE_ADDR        = "shippingservice.${var.service_discovery_namespace}:50051"
        PAYMENT_SERVICE_ADDR         = "paymentservice.${var.service_discovery_namespace}:50051"
        EMAIL_SERVICE_ADDR           = "emailservice.${var.service_discovery_namespace}:8080"
        CURRENCY_SERVICE_ADDR        = "currencyservice.${var.service_discovery_namespace}:7000"
        CART_SERVICE_ADDR            = "cartservice.${var.service_discovery_namespace}:7070"
      }
    }
    currencyservice = {
      port              = 7000
      cpu               = 256
      memory            = 512
      desired_count     = var.default_service_desired_count
      build_context     = "src/currencyservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT             = "7000"
        DISABLE_PROFILER = "1"
      }
    }
    emailservice = {
      port              = 8080
      cpu               = 256
      memory            = 512
      desired_count     = var.default_service_desired_count
      build_context     = "src/emailservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT             = "8080"
        DISABLE_PROFILER = "1"
      }
    }
    frontend = {
      port              = 8080
      cpu               = 512
      memory            = 1024
      desired_count     = var.frontend_desired_count
      build_context     = "src/frontend"
      service_discovery = true
      load_balanced     = true
      health_check_path = "/_healthz"
      environment = {
        PORT                         = "8080"
        PRODUCT_CATALOG_SERVICE_ADDR = "productcatalogservice.${var.service_discovery_namespace}:3550"
        CURRENCY_SERVICE_ADDR        = "currencyservice.${var.service_discovery_namespace}:7000"
        CART_SERVICE_ADDR            = "cartservice.${var.service_discovery_namespace}:7070"
        RECOMMENDATION_SERVICE_ADDR  = "recommendationservice.${var.service_discovery_namespace}:8080"
        SHIPPING_SERVICE_ADDR        = "shippingservice.${var.service_discovery_namespace}:50051"
        CHECKOUT_SERVICE_ADDR        = "checkoutservice.${var.service_discovery_namespace}:5050"
        AD_SERVICE_ADDR              = "adservice.${var.service_discovery_namespace}:9555"
        ENABLE_PROFILER              = "0"
        ENV_PLATFORM                 = "aws"
      }
    }
    loadgenerator = {
      port              = null
      cpu               = 512
      memory            = 1024
      desired_count     = var.loadgenerator_desired_count
      build_context     = "src/loadgenerator"
      service_discovery = false
      load_balanced     = false
      environment = {
        FRONTEND_ADDR = "frontend.${var.service_discovery_namespace}:8080"
        USERS         = "10"
      }
    }
    paymentservice = {
      port              = 50051
      cpu               = 256
      memory            = 512
      desired_count     = var.default_service_desired_count
      build_context     = "src/paymentservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT             = "50051"
        DISABLE_PROFILER = "1"
      }
    }
    productcatalogservice = {
      port              = 3550
      cpu               = 256
      memory            = 512
      desired_count     = var.default_service_desired_count
      build_context     = "src/productcatalogservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT             = "3550"
        DISABLE_PROFILER = "1"
      }
    }
    recommendationservice = {
      port              = 8080
      cpu               = 512
      memory            = 1024
      desired_count     = var.default_service_desired_count
      build_context     = "src/recommendationservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT                         = "8080"
        PRODUCT_CATALOG_SERVICE_ADDR = "productcatalogservice.${var.service_discovery_namespace}:3550"
        DISABLE_PROFILER             = "1"
      }
    }
    shippingservice = {
      port              = 50051
      cpu               = 256
      memory            = 512
      desired_count     = var.default_service_desired_count
      build_context     = "src/shippingservice"
      service_discovery = true
      load_balanced     = false
      environment = {
        PORT             = "50051"
        DISABLE_PROFILER = "1"
      }
    }
  }

  public_images = {
    redis-cart = "public.ecr.aws/docker/library/redis:7-alpine"
  }

  ecr_services = {
    for service, config in local.service_definitions : service => config
  }

  ecs_workloads = merge(
    local.service_definitions,
    {
      redis-cart = {
        port              = 6379
        cpu               = 256
        memory            = 512
        desired_count     = var.default_service_desired_count
        service_discovery = true
        load_balanced     = false
        environment       = {}
      }
    }
  )
}

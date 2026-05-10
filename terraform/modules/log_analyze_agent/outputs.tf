output "ecs" {
  value = {
    cluster = {
      arn  = module.ecs.cluster_arn
      name = module.ecs.cluster_name
    }
    services = {
      for key, service in module.ecs.services :
      key => {
        arn         = service.id
        name        = service.name
        task_family = service.task_definition_family
      }
    }
  }
}

output "sqs_queue" {
  value = {
    arn  = module.sqs.queue_arn
    name = module.sqs.queue_name
    url  = module.sqs.queue_url
  }
}

output "knowledge_bases" {
  value = {
    id             = aws_bedrockagent_knowledge_base.this.id
    data_source_id = aws_bedrockagent_data_source.this.data_source_id
    data_source_bucket = {
      arn  = module.kb_source_bucket.s3_bucket_arn
      name = module.kb_source_bucket.s3_bucket_id
    }
  }
}
output "kb_data_source_bucket" {
  value = {
    arn  = module.kb_source_bucket.s3_bucket_arn
    name = module.kb_source_bucket.s3_bucket_id
  }
}

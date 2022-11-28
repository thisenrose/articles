require "sinatra"
require "google/cloud/datastore"

# Configuração baśica do Sinatra
set(:bind, "0.0.0.0")
port = ENV["PORT"] || "8080"
set(:port, port)

before { content_type :json }

# Inicia o cli do Datastore
def build_datastore
  Google::Cloud::Datastore.new(
    project_id: ENV["GCP_PROJECT_ID"], credentials: "./credentials.json"
  )
end

# Escreve os tempos de execução ignando os testes que falharam
def write_run_times(specs)
  datastore = build_datastore
  now = Time.now
  datastore.transaction do
    specs.each do |spec_infos|
      next if spec_infos["status"] != "passed"

      spec_entity = datastore.entity "spec", spec_infos["id"] do |spec_entity|
        spec_entity["run_time"] = spec_infos["run_time"]
        spec_entity["updated_at"] = now
      end
      datastore.save spec_entity
    end
  end
end


# Carrega os tempos de execução armazenados no Datastore
def load_run_times
  datastore = build_datastore
  query = datastore.query("spec")
  specs = datastore.run(query)
  specs.map do |spec|
    { "id" => spec.key.name, "run_time" => spec["run_time"] }
  end
end

# Divide os specs em grupos com tempo total de execução equivalentes
def divide_equally_by_run_time(total_groups, specs)
  groups = (1..total_groups).map { { "total_time" => 0.0, "specs" => [] } }
  specs.each do |spec|
    min_group = groups.min_by { |group| group["total_time"] }
    min_group["specs"] << spec
    min_group["total_time"] += spec["run_time"]
  end

  groups
end

# Método auxiliar para incluir os specs que ainda não estão armazenados no Datastore
def merge_specs_with_run_times(specs, run_times)
  run_times_by_spec_id = run_times.each_with_object({}) { |spec, hash| hash[spec["id"]] = spec }
  specs.map do |spec|
    run_times_by_spec_id[spec["id"]] || { "id" => spec["id"], "run_time" => 0.5 }
  end
end

# Rota coletar os grupos com tempo total de execução equivalentes
post("/groups") do
  body = JSON.parse(request.body.read)
  specs = (body["specs"] || { "examples" => [] })["examples"]
  run_times = load_run_times
  spec_with_run_times = merge_specs_with_run_times(specs, run_times)
  groups = divide_equally_by_run_time(body["total_groups"] || 16, spec_with_run_times)
  status(200)
  body(groups.to_json)
end

# Rota para escrever os tempos de execução
post("/write_run_times") do
  body = JSON.parse(request.body.read)
  specs = (body["specs"] || { "examples" => [] })["examples"]
  write_run_times(specs)
  status(200)
end
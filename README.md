# gitops-infra — Fuente de Verdad del Curso GitOps

Repositorio de **infraestructura y configuración** del curso. Contiene los archivos de Terraform para crear la EC2 en AWS y los manifiestos de Kubernetes que ArgoCD despliega automáticamente en el cluster K3s.

> **Regla GitOps:** este repositorio es la **única fuente de verdad** del cluster. ArgoCD lo observa constantemente. Si quieres cambiar algo en producción, lo cambias aquí — nunca con `kubectl apply` directo.

> Jenkins es el único que hace `git push` a este repo de forma automática (actualiza el tag de la imagen en `deployment.yaml`).

---

## ¿Qué hay en este repositorio?

### Terraform
Código de infraestructura para crear en AWS:
- Un bucket S3 + tabla DynamoDB (backend para el state de Terraform)
- Una instancia EC2 t3.micro con su Security Group (el servidor donde vive K3s)

### Kubernetes (7 manifiestos)
Los recursos que ArgoCD despliega en el namespace `curso-gitops`:
- MySQL con su ConfigMap (init.sql), Secrets y Service interno
- La app Go con sus variables de entorno, probes y Service NodePort

### ArgoCD
El manifiesto que conecta ArgoCD con este repositorio y define qué desplegar y dónde.

---

## Estructura completa del repositorio

```
gitops-infra/
│
├── infrastructure/
│   │
│   ├── terraform/
│   │   │
│   │   ├── backend/
│   │   │   ├── main.tf          # Crea el bucket S3 y la tabla DynamoDB
│   │   │   │                    # S3: versionado + encriptación AES256 + acceso público bloqueado
│   │   │   │                    # DynamoDB: tabla "LockID" con PAY_PER_REQUEST
│   │   │   │                    # prevent_destroy=true en el bucket (protege contra borrado accidental)
│   │   │   ├── variables.tf     # region, bucket_name, dynamodb_table_name
│   │   │   └── outputs.tf       # bucket_name, bucket_arn, dynamodb_table_name
│   │   │
│   │   └── jenkins-ec2/
│   │       ├── main.tf          # Crea aws_security_group + aws_instance
│   │       │                    # Security Group: puertos 22, 30080, 30081, 6443
│   │       │                    # EC2: t3.micro, Ubuntu 22.04, disco 30GB gp3 encriptado
│   │       │                    # Backend S3 configurado (guarda el state en la nube)
│   │       ├── variables.tf     # region, ami_id, instance_type, key_name, allowed_cidr
│   │       └── outputs.tf       # prod_public_ip, prod_public_dns, argocd_url, app_url
│   │
│   └── kubernetes/
│       │
│       ├── app/                 ← ArgoCD observa exactamente esta carpeta
│       │   ├── namespace.yaml       # Namespace: curso-gitops
│       │   ├── secrets.yaml         # db-credentials (usuario+contraseña MySQL) + app-secrets (JWT)
│       │   ├── mysql-configmap.yaml # Script init.sql montado en /docker-entrypoint-initdb.d/
│       │   ├── mysql-deployment.yaml# Pod MySQL 8.0 con limits (256Mi RAM), secretKeyRef, liveness probe
│       │   ├── mysql-service.yaml   # Service ClusterIP "mysql-svc" en puerto 3306 (solo interno)
│       │   ├── deployment.yaml      # Pod app Go — Jenkins actualiza la línea "image:" con sed
│       │   └── service.yaml         # Service NodePort 30081 → accesible en http://<IP_EC2>:30081
│       │
│       └── argocd/
│           └── application.yaml # Application de ArgoCD: conecta este repo con el cluster K3s
│                                # automated sync + prune + selfHeal + CreateNamespace=true
│
├── .gitignore                   # Excluye *.pem, *.tfstate, .terraform/, kubeconfig
└── README.md                    # Este archivo
```

---

## En qué episodios se usa cada archivo

### Terraform

| Archivo | Episodio | Qué se hace exactamente |
|---|---|---|
| `backend/main.tf` | **EP17 — S3 y DynamoDB** | Se explica el problema del state local y se crea el backend remoto. Se muestra el `prevent_destroy=true` |
| `backend/variables.tf` | **EP17** | Se revisan las variables y se explica por qué el nombre del bucket es único global en S3 |
| `backend/outputs.tf` | **EP17** | Se muestran los outputs para verificar que los recursos se crearon |
| `backend/` (aplicar) | **EP20 — Backend remoto** | Se ejecuta `terraform init && terraform apply` en esta carpeta por primera y única vez |
| `jenkins-ec2/main.tf` | **EP19 — Primeros pasos IaC** | Se lee el archivo para entender los bloques HCL (provider, resource, variable) antes de escribirlos desde cero en un ejemplo |
| `jenkins-ec2/main.tf` | **EP21 — Comandos esenciales** | Se ejecuta `terraform plan` y se lee el output en voz alta — práctica del ciclo init → validate → plan → apply |
| `jenkins-ec2/variables.tf` | **EP22 — EC2 para K3s** | Se muestra que `instance_type = "t3.micro"` es la clave que hace el stack gratuito |
| `jenkins-ec2/` (aplicar) | **EP22** | Se ejecuta `terraform apply -var="key_name=aws-key"` — se crea el servidor de producción |
| `jenkins-ec2/outputs.tf` | **EP22** | Se muestra la IP pública que se usará en EP28, EP30 y EP39 |
| `jenkins-ec2/` (destruir) | **EP49 — Limpieza** | Se ejecuta `terraform destroy` — se elimina la EC2 y el Security Group |

### Kubernetes

| Archivo | Episodio | Qué se hace exactamente |
|---|---|---|
| `namespace.yaml` | **EP25 — Primer despliegue K8s** | Se explica qué es un namespace y para qué sirve el aislamiento |
| `secrets.yaml` | **EP47 — BD separada y manifiestos** | Se explica que Base64 no es cifrado, cómo generar los valores y por qué usar `secretKeyRef` en lugar de poner la contraseña directamente |
| `mysql-configmap.yaml` | **EP47** | Se explica la diferencia entre Secret (datos sensibles) y ConfigMap (configuración). Se muestra que MySQL ejecuta el SQL automáticamente en `/docker-entrypoint-initdb.d/` |
| `mysql-deployment.yaml` | **EP47** | Se explica `resources.limits` (crítico en t3.micro), `secretKeyRef`, y por qué MySQL no puede ir en el mismo pod que la app |
| `mysql-service.yaml` | **EP47** | Se explica ClusterIP vs NodePort y por qué MySQL debe ser solo interno |
| `deployment.yaml` | **EP47** | Se explica `readinessProbe`, `livenessProbe`, `replicas: 1`, y que Jenkins actualiza la línea `image:` con `sed` en cada build |
| `service.yaml` | **EP47** | Se explica por qué NodePort en lugar de LoadBalancer (LoadBalancer queda en `<pending>` en K3s sin cloud provider) |
| Todos los manifiestos | **EP40 — Crear Application en ArgoCD** | Se verifica que los 7 archivos existen en el repositorio antes de conectar ArgoCD |
| `deployment.yaml` (línea image:) | **EP41 — Despliegue automático** | Se demuestra cómo Jenkins actualiza esta línea y ArgoCD detecta el cambio |
| `deployment.yaml` (línea image:) | **EP48 — Pipeline en acción** | Se observa en tiempo real cómo la línea cambia y cómo ArgoCD hace el rolling update |

### ArgoCD

| Archivo | Episodio | Qué se hace exactamente |
|---|---|---|
| `argocd/application.yaml` | **EP40 — Crear Application** | Se aplica con `kubectl apply -f` como alternativa al formulario de la UI. Se explica cada campo: `repoURL`, `path`, `destination`, `syncPolicy` |
| `argocd/application.yaml` | **EP41 — Despliegue automático** | Se muestra que `selfHeal: true` revierte cambios manuales en el cluster |

---

## Guía de uso paso a paso

### Paso 1 — Crear el backend de Terraform (EP17 / EP20)

> Solo se hace **una vez** al inicio del curso. El bucket S3 y la tabla DynamoDB sobreviven hasta el final.

```bash
cd infrastructure/terraform/backend

# Inicializar con backend local (es el único directorio que NO tiene backend remoto)
terraform init

# Ver qué se va a crear
terraform plan

# Crear el bucket S3 + tabla DynamoDB
terraform apply -auto-approve
```

Verificar:

```bash
aws s3 ls | grep curso-gitops-terraform-state
# Debe aparecer el bucket

aws dynamodb describe-table \
  --table-name curso-gitops-terraform-locks \
  --query "Table.TableStatus" --output text
# ACTIVE
```

---

### Paso 2 — Crear la EC2 K3s (EP22)

```bash
cd infrastructure/terraform/jenkins-ec2

# Crear el Key Pair SSH (si no existe ya)
aws ec2 create-key-pair \
  --key-name aws-key \
  --query 'KeyMaterial' \
  --output text > aws-key.pem
chmod 400 aws-key.pem
# aws-key.pem está en .gitignore — nunca sube al repositorio

# Inicializar — conecta con el backend S3
terraform init
# Debe mostrar: "Successfully configured the backend "s3"!"

# Leer el plan antes de crear nada
terraform plan -var="key_name=aws-key"
# Debe mostrar: Plan: 2 to add, 0 to change, 0 to destroy.
# (Security Group + EC2)

# Crear
terraform apply -var="key_name=aws-key" -auto-approve
```

Al terminar verás:

```
Outputs:
prod_public_ip = "54.x.x.x"      ← anota esta IP
argocd_url     = "http://54.x.x.x:30080"
app_url        = "http://54.x.x.x:30081"
```

Verificar:

```bash
# Conectar por SSH
ssh -i aws-key.pem ubuntu@$(terraform output -raw prod_public_ip)

# Dentro de la EC2
free -h    # ~981MB RAM
df -h /    # ~29GB disco
nproc      # 1 CPU
exit
```

---

### Paso 3 — Configurar K3s en la EC2 (EP28 + EP29 + EP30)

```bash
# SSH a la EC2
ssh -i aws-key.pem ubuntu@<IP_EC2>

# EP28 — Configurar Swap de 2GB (crítico para K3s + ArgoCD en 1GB RAM)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Verificar
free -h
# Swap: 2.0Gi

# EP29 — Instalar K3s
curl -sfL https://get.k3s.io | sh -

# Verificar
sudo kubectl get nodes
# NAME   STATUS   ROLES                  AGE   VERSION
# ip-... Ready    control-plane,master   ...   v1.28.x+k3s1

# Copiar kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config

exit

# EP30 — Configurar kubectl local
IP_EC2="54.x.x.x"  # tu IP real

# Descargar el kubeconfig
scp -i aws-key.pem ubuntu@${IP_EC2}:~/.kube/config ~/.kube/k3s-config

# Reemplazar 127.0.0.1 por la IP pública
sed -i "s/127.0.0.1/${IP_EC2}/g" ~/.kube/k3s-config

# Activar
export KUBECONFIG=~/.kube/k3s-config
echo 'export KUBECONFIG=~/.kube/k3s-config' >> ~/.bashrc

# Verificar desde tu PC local
kubectl get nodes
# ip-... Ready control-plane,master
```

---

### Paso 4 — Instalar ArgoCD (EP38 + EP39)

```bash
# EP38 — Instalar
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que todos los pods estén Running (~3-5 minutos en t3.micro)
kubectl get pods -n argocd -w

# EP39 — Exponer con NodePort en puerto 30080
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "targetPort": 8080, "nodePort": 30080}]}}'

# Obtener contraseña inicial
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

# Acceder en el navegador
# http://<IP_EC2>:30080
# Usuario: admin / Contraseña: (la del comando anterior)
```

---

### Paso 5 — Conectar ArgoCD a este repositorio (EP40)

```bash
# Aplicar la Application (recuerda cambiar TU_USUARIO_GITHUB primero)
sed -i 's/TU_USUARIO_GITHUB/tu-usuario-real/g' \
  infrastructure/kubernetes/argocd/application.yaml

kubectl apply -f infrastructure/kubernetes/argocd/application.yaml
```

Antes de aplicar, debes conectar el repositorio privado en ArgoCD:
1. Abrir `http://<IP_EC2>:30080`
2. Settings → Repositories → Connect Repo
3. Method: HTTPS
4. URL: `https://github.com/TU_USUARIO_GITHUB/gitops-infra.git`
5. Username: tu usuario de GitHub
6. Password: tu PAT con scope `repo`

---

### Paso 6 — Verificar que ArgoCD desplegó los manifiestos

```bash
# Estado de la Application
kubectl get application curso-gitops -n argocd
# NAME          SYNC STATUS   HEALTH STATUS
# curso-gitops  Synced        Healthy

# Pods corriendo en el namespace del curso
kubectl get pods -n curso-gitops
# mysql-...         1/1   Running
# curso-gitops-...  1/1   Running

# Verificar que la app responde
curl http://<IP_EC2>:30081/api/health
# {"success":true,"message":"ok"}
```

---

### Paso 7 — Destruir todo al terminar el curso (EP49)

```bash
cd infrastructure/terraform/jenkins-ec2

# Ver qué se va a destruir
terraform plan -destroy -var="key_name=aws-key"

# Destruir la EC2 y el Security Group
terraform destroy -var="key_name=aws-key" -auto-approve

# Verificar que no quedan instancias corriendo
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text
# (silencio — ninguna instancia)
```

> El bucket S3 y la tabla DynamoDB **no se destruyen** aquí porque tienen `prevent_destroy = true`. Su costo mensual es prácticamente $0. Si quieres eliminarlos también, ve a `infrastructure/terraform/backend/`, quita `prevent_destroy = true` de `main.tf` y ejecuta `terraform destroy -auto-approve`.

---

## Detalles técnicos — manifiestos de Kubernetes

### ¿Por qué 7 archivos y no uno solo?

Kubernetes separa responsabilidades en objetos distintos. Cada archivo tiene una función específica:

| Manifiesto | Objeto K8s | Responsabilidad |
|---|---|---|
| `namespace.yaml` | Namespace | Aísla todos los recursos del curso en `curso-gitops` |
| `secrets.yaml` | Secret | Guarda credenciales en Base64 con control de acceso de K8s |
| `mysql-configmap.yaml` | ConfigMap | Guarda el SQL de inicialización (no sensible, no es Secret) |
| `mysql-deployment.yaml` | Deployment | Gestiona el ciclo de vida del pod MySQL |
| `mysql-service.yaml` | Service (ClusterIP) | Da un DNS estable (`mysql-svc`) al pod MySQL dentro del cluster |
| `deployment.yaml` | Deployment | Gestiona el ciclo de vida de la app Go |
| `service.yaml` | Service (NodePort) | Expone la app al mundo exterior en el puerto 30081 |

### ¿Por qué ClusterIP para MySQL y NodePort para la app?

- **MySQL (`ClusterIP`):** la base de datos nunca debe ser accesible desde fuera del cluster. Solo la app Go puede conectarse, y lo hace usando el DNS interno `mysql-svc:3306`.
- **App Go (`NodePort`):** debe ser accesible desde el navegador. NodePort expone el servicio directamente en un puerto de la EC2 (30081), sin necesitar un LoadBalancer de AWS.

### ¿Por qué `resources.limits` en los Deployments?

La EC2 t3.micro tiene solo 1GB de RAM. Sin límites, un pod podría consumir toda la memoria y dejar sin recursos a K3s, ArgoCD o los otros pods. Con los límites configurados:

| Pod | RAM máxima | RAM mínima |
|---|---|---|
| MySQL | 256Mi | 128Mi |
| App Go | 128Mi | 32Mi |
| K3s (sistema) | ~200Mi | — |
| ArgoCD (varios pods) | ~400-500Mi | — |

El total máximo cabe en los 1GB de RAM + 2GB de Swap configurados en EP28.

### ¿Por qué `readinessProbe` y `livenessProbe` en la app Go?

- **`readinessProbe`:** K3s solo envía tráfico al pod cuando pasa esta probe. Durante el rolling update, el pod nuevo debe pasar la readiness antes de que el pod viejo se elimine — esto garantiza cero downtime.
- **`livenessProbe`:** si la app se cuelga y deja de responder, K3s reinicia el pod automáticamente. Sin esta probe, un pod zombi seguiría corriendo sin servir tráfico.

Ambas prueban `GET /api/health` que devuelve 200 sin conectarse a la base de datos.

---

## Qué cambiar antes de usar este repositorio

| Placeholder | Reemplazar con | Archivos afectados |
|---|---|---|
| `TU_USUARIO_GITHUB` | Tu usuario de GitHub | `argocd/application.yaml` |
| `TU_USUARIO_DOCKERHUB` | Tu usuario de Docker Hub | `kubernetes/app/deployment.yaml` (línea `image:`) |

```bash
# Reemplazar en application.yaml
sed -i 's/TU_USUARIO_GITHUB/johndoe/g' \
  infrastructure/kubernetes/argocd/application.yaml

# Reemplazar en deployment.yaml
sed -i 's/TU_USUARIO_DOCKERHUB/johndoe/g' \
  infrastructure/kubernetes/app/deployment.yaml
```

---

## Archivos que Jenkins modifica automáticamente

Jenkins actualiza este archivo en cada build con el comando `sed`:

```
infrastructure/kubernetes/app/deployment.yaml
```

Línea que cambia:

```yaml
# Antes del build N+1:
image: johndoe/curso-gitops:5-a3b8d1c

# Después del build N+1 (Jenkins hace git push con este cambio):
image: johndoe/curso-gitops:6-f4c9e2a
```

**No edites esta línea manualmente.** Si lo haces y hay un pipeline corriendo, Jenkins sobreescribirá tu cambio en el próximo build.

---

## Archivos que NUNCA debes subir a GitHub

El `.gitignore` ya los excluye, pero como recordatorio:

| Archivo | Razón |
|---|---|
| `aws-key.pem` | Clave privada SSH — acceso total al servidor |
| `*.tfstate` | Puede contener IPs, ARNs y contraseñas en texto plano |
| `.terraform/` | Binarios de providers descargados — se regeneran con `terraform init` |
| `k3s-remote.yaml` / `kubeconfig` | Acceso total al cluster K3s |
| `.env` | Variables de entorno con secretos |

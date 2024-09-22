%{"v1/ResourceQuota/status" => "api/v1/namespaces/:namespace/resourcequotas/:name/status", "v1/Pod/ephemeralcontainers" => "api/v1/namespaces/:namespace/pods/:name/ephemeralcontainers", "autoscaling/v1/HorizontalPodAutoscaler/status" => "apis/autoscaling/v1/namespaces/:namespace/horizontalpodautoscalers/:name/status", "storage.k8s.io/v1alpha1/VolumeAttributesClass/" => "apis/storage.k8s.io/v1alpha1/volumeattributesclasses/:name/", "flowcontrol.apiserver.k8s.io/v1beta3/FlowSchema/" => "apis/flowcontrol.apiserver.k8s.io/v1beta3/flowschemas/:name/", "apps/v1/Scale/scale" => "apis/apps/v1/namespaces/:namespace/statefulsets/:name/scale", "v1/Service/status" => "api/v1/namespaces/:namespace/services/:name/status", "v1/Node/status/status" => "api/v1/nodes/:name", "authentication.k8s.io/v1/TokenReview/" => "apis/authentication.k8s.io/v1/tokenreviews/:name/", "authorization.k8s.io/v1/SelfSubjectAccessReview/" => "apis/authorization.k8s.io/v1/selfsubjectaccessreviews/:name/", "v1/Namespace//" => "api/v1/namespaces/:name", "v1/Endpoints/" => "api/v1/namespaces/:namespace/endpoints/:name/", "storage.k8s.io/v1/StorageClass/" => "apis/storage.k8s.io/v1/storageclasses/:name/", "policy/v1/PodDisruptionBudget/" => "apis/policy/v1/namespaces/:namespace/poddisruptionbudgets/:name/", "v1/Eviction/eviction" => "api/v1/namespaces/:namespace/pods/:name/eviction", "admissionregistration.k8s.io/v1alpha1/ValidatingAdmissionPolicyBinding/" => "apis/admissionregistration.k8s.io/v1alpha1/validatingadmissionpolicybindings/:name/", "coordination.k8s.io/v1alpha1/LeaseCandidate/" => "apis/coordination.k8s.io/v1alpha1/namespaces/:namespace/leasecandidates/:name/", "rbac.authorization.k8s.io/v1/ClusterRoleBinding/" => "apis/rbac.authorization.k8s.io/v1/clusterrolebindings/:name/", "certificates.k8s.io/v1alpha1/ClusterTrustBundle/" => "apis/certificates.k8s.io/v1alpha1/clustertrustbundles/:name/", "resource.k8s.io/v1alpha3/PodSchedulingContext/" => "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/podschedulingcontexts/:name/", "v1/Namespace/finalize/finalize" => "api/v1/namespaces/:name", "certificates.k8s.io/v1/CertificateSigningRequest/" => "apis/certificates.k8s.io/v1/certificatesigningrequests/:name/", "apiextensions.k8s.io/v1/CustomResourceDefinition/status" => "apis/apiextensions.k8s.io/v1/customresourcedefinitions/:name/status", "authentication.k8s.io/v1/SelfSubjectReview/" => "apis/authentication.k8s.io/v1/selfsubjectreviews/:name/", "storage.k8s.io/v1/CSIStorageCapacity/" => "apis/storage.k8s.io/v1/namespaces/:namespace/csistoragecapacities/:name/", "networking.k8s.io/v1/IngressClass/" => "apis/networking.k8s.io/v1/ingressclasses/:name/", "v1/Scale/scale" => "api/v1/namespaces/:namespace/replicationcontrollers/:name/scale", "flowcontrol.apiserver.k8s.io/v1/PriorityLevelConfiguration/" => "apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/:name/", "admissionregistration.k8s.io/v1beta1/ValidatingAdmissionPolicyBinding/" => "apis/admissionregistration.k8s.io/v1beta1/validatingadmissionpolicybindings/:name/", "v1/ReplicationController/" => "api/v1/namespaces/:namespace/replicationcontrollers/:name/", "apiregistration.k8s.io/v1/APIService/" => "apis/apiregistration.k8s.io/v1/apiservices/:name/", "apiextensions.k8s.io/v1/CustomResourceDefinition/" => "apis/apiextensions.k8s.io/v1/customresourcedefinitions/:name/", "v1/Binding/" => "api/v1/namespaces/:namespace/bindings/:name/", "authorization.k8s.io/v1/LocalSubjectAccessReview/" => "apis/authorization.k8s.io/v1/namespaces/:namespace/localsubjectaccessreviews/:name/", "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicy/" => "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/:name/", "v1/ServiceAccount/" => "api/v1/namespaces/:namespace/serviceaccounts/:name/", "storage.k8s.io/v1beta1/VolumeAttributesClass/" => "apis/storage.k8s.io/v1beta1/volumeattributesclasses/:name/", "networking.k8s.io/v1/Ingress/" => "apis/networking.k8s.io/v1/namespaces/:namespace/ingresses/:name/", "scheduling.k8s.io/v1/PriorityClass/" => "apis/scheduling.k8s.io/v1/priorityclasses/:name/", "batch/v1/CronJob/status" => "apis/batch/v1/namespaces/:namespace/cronjobs/:name/status", "v1/Event/" => "api/v1/namespaces/:namespace/events/:name/", "flowcontrol.apiserver.k8s.io/v1beta3/PriorityLevelConfiguration/status" => "apis/flowcontrol.apiserver.k8s.io/v1beta3/prioritylevelconfigurations/:name/status", "internal.apiserver.k8s.io/v1alpha1/StorageVersion/" => "apis/internal.apiserver.k8s.io/v1alpha1/storageversions/:name/", "batch/v1/Job/status" => "apis/batch/v1/namespaces/:namespace/jobs/:name/status", "flowcontrol.apiserver.k8s.io/v1beta3/FlowSchema/status" => "apis/flowcontrol.apiserver.k8s.io/v1beta3/flowschemas/:name/status", "admissionregistration.k8s.io/v1/MutatingWebhookConfiguration/" => "apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations/:name/", "admissionregistration.k8s.io/v1alpha1/ValidatingAdmissionPolicy/" => "apis/admissionregistration.k8s.io/v1alpha1/validatingadmissionpolicies/:name/", "apps/v1/DaemonSet/" => "apis/apps/v1/namespaces/:namespace/daemonsets/:name/", "networking.k8s.io/v1beta1/IPAddress/" => "apis/networking.k8s.io/v1beta1/ipaddresses/:name/", "v1/PodTemplate/" => "api/v1/namespaces/:namespace/podtemplates/:name/", "storagemigration.k8s.io/v1alpha1/StorageVersionMigration/status" => "apis/storagemigration.k8s.io/v1alpha1/storageversionmigrations/:name/status", "v1/PersistentVolume/status/status" => "api/v1/persistentvolumes/:name", "rbac.authorization.k8s.io/v1/RoleBinding/" => "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/rolebindings/:name/", "flowcontrol.apiserver.k8s.io/v1/PriorityLevelConfiguration/status" => "apis/flowcontrol.apiserver.k8s.io/v1/prioritylevelconfigurations/:name/status", "policy/v1/PodDisruptionBudget/status" => "apis/policy/v1/namespaces/:namespace/poddisruptionbudgets/:name/status", "discovery.k8s.io/v1/EndpointSlice/" => "apis/discovery.k8s.io/v1/namespaces/:namespace/endpointslices/:name/", "storage.k8s.io/v1/CSIDriver/" => "apis/storage.k8s.io/v1/csidrivers/:name/", "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicy/status" => "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicies/:name/status", "apps/v1/Deployment/status" => "apis/apps/v1/namespaces/:namespace/deployments/:name/status", "authorization.k8s.io/v1/SelfSubjectRulesReview/" => "apis/authorization.k8s.io/v1/selfsubjectrulesreviews/:name/", "batch/v1/CronJob/" => "apis/batch/v1/namespaces/:namespace/cronjobs/:name/", "networking.k8s.io/v1beta1/ServiceCIDR/" => "apis/networking.k8s.io/v1beta1/servicecidrs/:name/", "networking.k8s.io/v1/NetworkPolicy/" => "apis/networking.k8s.io/v1/namespaces/:namespace/networkpolicies/:name/", "apiregistration.k8s.io/v1/APIService/status" => "apis/apiregistration.k8s.io/v1/apiservices/:name/status", "authentication.k8s.io/v1alpha1/SelfSubjectReview/" => "apis/authentication.k8s.io/v1alpha1/selfsubjectreviews/:name/", "coordination.k8s.io/v1/Lease/" => "apis/coordination.k8s.io/v1/namespaces/:namespace/leases/:name/", "resource.k8s.io/v1alpha3/ResourceSlice/" => "apis/resource.k8s.io/v1alpha3/resourceslices/:name/", "resource.k8s.io/v1alpha3/ResourceClaim/" => "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/resourceclaims/:name/", "v1/Namespace/status/status" => "api/v1/namespaces/:name", "apps/v1/DaemonSet/status" => "apis/apps/v1/namespaces/:namespace/daemonsets/:name/status", "autoscaling/v1/HorizontalPodAutoscaler/" => "apis/autoscaling/v1/namespaces/:namespace/horizontalpodautoscalers/:name/", "apps/v1/StatefulSet/" => "apis/apps/v1/namespaces/:namespace/statefulsets/:name/", "storage.k8s.io/v1/CSINode/" => "apis/storage.k8s.io/v1/csinodes/:name/", "v1/ResourceQuota/" => "api/v1/namespaces/:namespace/resourcequotas/:name/", "v1/Pod/" => "api/v1/namespaces/:namespace/pods/:name/", "v1/PersistentVolumeClaim/status" => "api/v1/namespaces/:namespace/persistentvolumeclaims/:name/status", "resource.k8s.io/v1alpha3/DeviceClass/" => "apis/resource.k8s.io/v1alpha3/deviceclasses/:name/", "flowcontrol.apiserver.k8s.io/v1beta3/PriorityLevelConfiguration/" => "apis/flowcontrol.apiserver.k8s.io/v1beta3/prioritylevelconfigurations/:name/", "admissionregistration.k8s.io/v1/ValidatingAdmissionPolicyBinding/" => "apis/admissionregistration.k8s.io/v1/validatingadmissionpolicybindings/:name/", "v1/Service/" => "api/v1/namespaces/:namespace/services/:name/", "v1/LimitRange/" => "api/v1/namespaces/:namespace/limitranges/:name/", "apps/v1/Deployment/" => "apis/apps/v1/namespaces/:namespace/deployments/:name/", "apps/v1/ReplicaSet/status" => "apis/apps/v1/namespaces/:namespace/replicasets/:name/status", "authorization.k8s.io/v1/SubjectAccessReview/" => "apis/authorization.k8s.io/v1/subjectaccessreviews/:name/", "admissionregistration.k8s.io/v1beta1/ValidatingAdmissionPolicy/" => "apis/admissionregistration.k8s.io/v1beta1/validatingadmissionpolicies/:name/", "v1/ConfigMap/" => "api/v1/namespaces/:namespace/configmaps/:name/", "internal.apiserver.k8s.io/v1alpha1/StorageVersion/status" => "apis/internal.apiserver.k8s.io/v1alpha1/storageversions/:name/status", "certificates.k8s.io/v1/CertificateSigningRequest/approval" => "apis/certificates.k8s.io/v1/certificatesigningrequests/:name/approval", "resource.k8s.io/v1alpha3/ResourceClaim/status" => "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/resourceclaims/:name/status", "storagemigration.k8s.io/v1alpha1/StorageVersionMigration/" => "apis/storagemigration.k8s.io/v1alpha1/storageversionmigrations/:name/", "storage.k8s.io/v1/VolumeAttachment/status" => "apis/storage.k8s.io/v1/volumeattachments/:name/status", "resource.k8s.io/v1alpha3/ResourceClaimTemplate/" => "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/resourceclaimtemplates/:name/", "v1/Secret/" => "api/v1/namespaces/:namespace/secrets/:name/", "networking.k8s.io/v1beta1/ServiceCIDR/status" => "apis/networking.k8s.io/v1beta1/servicecidrs/:name/status", "authentication.k8s.io/v1beta1/SelfSubjectReview/" => "apis/authentication.k8s.io/v1beta1/selfsubjectreviews/:name/", "rbac.authorization.k8s.io/v1/ClusterRole/" => "apis/rbac.authorization.k8s.io/v1/clusterroles/:name/", "v1/TokenRequest/token" => "api/v1/namespaces/:namespace/serviceaccounts/:name/token", "apps/v1/ReplicaSet/" => "apis/apps/v1/namespaces/:namespace/replicasets/:name/", "v1/Binding/binding" => "api/v1/namespaces/:namespace/pods/:name/binding", "apps/v1/StatefulSet/status" => "apis/apps/v1/namespaces/:namespace/statefulsets/:name/status", "rbac.authorization.k8s.io/v1/Role/" => "apis/rbac.authorization.k8s.io/v1/namespaces/:namespace/roles/:name/", "batch/v1/Job/" => "apis/batch/v1/namespaces/:namespace/jobs/:name/", "v1/Pod/status" => "api/v1/namespaces/:namespace/pods/:name/status", "v1/Node//" => "api/v1/nodes/:name", "certificates.k8s.io/v1/CertificateSigningRequest/status" => "apis/certificates.k8s.io/v1/certificatesigningrequests/:name/status", "flowcontrol.apiserver.k8s.io/v1/FlowSchema/" => "apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/:name/", "node.k8s.io/v1/RuntimeClass/" => "apis/node.k8s.io/v1/runtimeclasses/:name/", "events.k8s.io/v1/Event/" => "apis/events.k8s.io/v1/namespaces/:namespace/events/:name/", "autoscaling/v2/HorizontalPodAutoscaler/" => "apis/autoscaling/v2/namespaces/:namespace/horizontalpodautoscalers/:name/", "v1/PersistentVolumeClaim/" => "api/v1/namespaces/:namespace/persistentvolumeclaims/:name/", "admissionregistration.k8s.io/v1alpha1/ValidatingAdmissionPolicy/status" => "apis/admissionregistration.k8s.io/v1alpha1/validatingadmissionpolicies/:name/status", "admissionregistration.k8s.io/v1/ValidatingWebhookConfiguration/" => "apis/admissionregistration.k8s.io/v1/validatingwebhookconfigurations/:name/", "autoscaling/v2/HorizontalPodAutoscaler/status" => "apis/autoscaling/v2/namespaces/:namespace/horizontalpodautoscalers/:name/status", "storage.k8s.io/v1/VolumeAttachment/" => "apis/storage.k8s.io/v1/volumeattachments/:name/", "v1/PersistentVolume//" => "api/v1/persistentvolumes/:name", "v1/ReplicationController/status" => "api/v1/namespaces/:namespace/replicationcontrollers/:name/status", "apps/v1/ControllerRevision/" => "apis/apps/v1/namespaces/:namespace/controllerrevisions/:name/", "flowcontrol.apiserver.k8s.io/v1/FlowSchema/status" => "apis/flowcontrol.apiserver.k8s.io/v1/flowschemas/:name/status", "networking.k8s.io/v1/Ingress/status" => "apis/networking.k8s.io/v1/namespaces/:namespace/ingresses/:name/status", "resource.k8s.io/v1alpha3/PodSchedulingContext/status" => "apis/resource.k8s.io/v1alpha3/namespaces/:namespace/podschedulingcontexts/:name/status", "v1/ComponentStatus//" => "api/v1/componentstatuses/:name", "admissionregistration.k8s.io/v1beta1/ValidatingAdmissionPolicy/status" => "apis/admissionregistration.k8s.io/v1beta1/validatingadmissionpolicies/:name/status"}
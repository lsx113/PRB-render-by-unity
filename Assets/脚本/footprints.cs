using UnityEngine;

public class footprints : MonoBehaviour
{
    public ParticleSystem footPS;       // 粒子系统
    public float emitDistance = 0.5f;   // 每移动多远发射一次

    private Vector3 lastEmitPos;

    void Start()
    {
        lastEmitPos = transform.position;

    }

    void Update()
    {
        if (Vector3.Distance(transform.position, lastEmitPos) > emitDistance)
        {
            lastEmitPos = transform.position;
            EmitFootprint();
        }
    }

    void EmitFootprint()
    {
        Vector3 footPos = transform.position;
        footPos.y += 0.01f;   // 稍微抬高，避免和地面重叠

        footPS.Emit(new ParticleSystem.EmitParams { position = footPos }, 1);
    }
}
